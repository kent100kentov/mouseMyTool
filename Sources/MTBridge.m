#import "MTBridge.h"
#import <dlfcn.h>
#import <stdatomic.h>
#import <math.h>
#import <stddef.h>
// Reverse-engineered ABI, deliberately isolated from the application and recognizer.
typedef struct { float x,y; } MTPointABI;
typedef struct { MTPointABI position,velocity; } Vector;
typedef struct {
 int32_t frame; double timestamp; int32_t path,state,identity,hand;
 Vector normalized; float size; int32_t unused; float angle,major,minor;
 Vector absolute; int32_t field14,field15; float density;
} Contact;
_Static_assert(sizeof(Contact)==96, "Unexpected multitouch ABI");
_Static_assert(offsetof(Contact,normalized)==32, "Unexpected position offset");
typedef void (*FrameCB)(CFTypeRef, Contact *, int, double, int, void *);
static CFArrayRef (*createList)(void);
static void (*registerCB)(CFTypeRef,FrameCB,void *);
static void (*unregisterCB)(CFTypeRef,FrameCB);
static int (*startDevice)(CFTypeRef,int);
static void (*stopDevice)(CFTypeRef);
static bool (*builtIn)(CFTypeRef);
static int (*familyID)(CFTypeRef,int *), (*driverType)(CFTypeRef,int *);
static int (*dimensions)(CFTypeRef,int *,int *);
// A process-lifetime target avoids dangling refcons even if private API delivers late callbacks.
static MTBridge *owner;
static _Atomic(uint64_t) generation;
static bool loadAPI(void) {
 static bool loaded; static dispatch_once_t once;
 dispatch_once(&once, ^{
  void *h=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_NOW|RTLD_LOCAL);
  if(!h) return;
#define SYM(v,n) v=dlsym(h,n)
  SYM(createList,"MTDeviceCreateList"); SYM(registerCB,"MTRegisterContactFrameCallbackWithRefcon");
  SYM(unregisterCB,"MTUnregisterContactFrameCallback"); SYM(startDevice,"MTDeviceStart");
  SYM(stopDevice,"MTDeviceStop"); SYM(builtIn,"MTDeviceIsBuiltIn");
  SYM(familyID,"MTDeviceGetFamilyID"); SYM(driverType,"MTDeviceGetDriverType");
  SYM(dimensions,"MTDeviceGetSensorSurfaceDimensions");
  loaded=createList&&registerCB&&unregisterCB&&startDevice&&stopDevice&&builtIn&&familyID&&driverType&&dimensions;
  // Keep the framework loaded for the entire process, including late callback code.
 }); return loaded;
}
static BOOL isMouse(CFTypeRef d) {
 int f=0,t=0,w=0,h=0;
 return !builtIn(d)&&familyID(d,&f)==0&&driverType(d,&t)==0&&dimensions(d,&w,&h)==0
  &&f==112&&t==4&&w==5152&&h==9056;
}
@interface MTBridge ()
@property(nonatomic) CFArrayRef devices;
@property(nonatomic) NSMutableArray<NSValue *> *active;
@end
static void receive(CFTypeRef device, Contact *touches, int count, double time, int frame, void *context) {
 uint64_t epoch=(uint64_t)(uintptr_t)context;
 if(epoch!=atomic_load(&generation)) return;
 BOOL valid=count>=0&&count<=16&&isfinite(time)&&(!count||touches);
 if(!valid) count=0;
 MTContact copied[16];
 for(int i=0;i<count;i++) {
  Contact c=touches[i];
  if(c.state<0||c.state>7||!isfinite(c.normalized.position.x)||!isfinite(c.normalized.position.y)
    ||c.normalized.position.x<-.1||c.normalized.position.x>1.1||c.normalized.position.y<-.1||c.normalized.position.y>1.1) { valid=NO; break; }
  copied[i]=(MTContact){c.identity,c.state,c.normalized.position.x,c.normalized.position.y};
 }
 NSData *data=valid ? [NSData dataWithBytes:copied length:count*sizeof(MTContact)] : [NSData data];
 uint64_t deviceID=(uint64_t)(uintptr_t)device;
 double receivedAt=NSProcessInfo.processInfo.systemUptime;
 dispatch_async(dispatch_get_main_queue(), ^{
  if(epoch!=atomic_load(&generation)) return;
  if(owner.handler) owner.handler(deviceID,data.bytes,!valid || NSProcessInfo.processInfo.systemUptime-receivedAt > 0.15 ? -1 : count,time);
 });
}
@implementation MTBridge
- (NSString *)diagnostics {
 NSAssert(NSThread.isMainThread,@"Main thread required");
 if(!loadAPI()) return @"MultitouchSupport: required symbols unavailable; disabled.";
 CFArrayRef list=createList();
 NSMutableString *s=[NSMutableString stringWithString:@"MultitouchSupport: required symbols OK; expected Contact ABI 96 bytes (not runtime-verified).\n"];
 if(list) { for(CFIndex i=0;i<CFArrayGetCount(list);i++) {
  CFTypeRef d=CFArrayGetValueAtIndex(list,i); int f=0,t=0,w=0,h=0;
  familyID(d,&f);driverType(d,&t);dimensions(d,&w,&h);
  [s appendFormat:@"device %ld: built-in=%d family=%d driver=%d surface=%dx%d selected=%d\n",(long)i,builtIn(d),f,t,w,h,isMouse(d)];
 } CFRelease(list); }
 return s;
}
- (NSInteger)start {
 NSAssert(NSThread.isMainThread,@"Main thread required");
 [self stop]; if(!loadAPI()) return -1;
 owner=self; self.active=[NSMutableArray new]; self.devices=createList();
 uint64_t epoch=atomic_fetch_add(&generation,1)+1;
 if(!self.devices) return 0;
 for(CFIndex i=0;i<CFArrayGetCount(self.devices);i++) {
  CFTypeRef d=CFArrayGetValueAtIndex(self.devices,i); if(!isMouse(d)) continue;
  registerCB(d,receive,(void *)(uintptr_t)epoch);
  if(startDevice(d,0)==0) [self.active addObject:[NSValue valueWithPointer:d]];
  else { stopDevice(d); unregisterCB(d,receive); }
 }
 return self.active.count;
}
- (void)stop {
 NSAssert(NSThread.isMainThread,@"Main thread required");
 atomic_fetch_add(&generation,1);
 for(NSValue *v in self.active) { stopDevice(v.pointerValue); unregisterCB(v.pointerValue,receive); }
 [self.active removeAllObjects];
 if(self.devices) { CFRelease(self.devices); self.devices=NULL; }
}
@end

#import <IOKit/IOKitLib.h>
static IONotificationPortRef notificationPort;
static io_iterator_t addedIterator, removedIterator;
static void (^deviceChanged)(void);
static void drainDevices(void *context, io_iterator_t iterator) {
 if(!iterator) return;
 io_service_t service; BOOL any=NO;
 while((service=IOIteratorNext(iterator))) { IOObjectRelease(service); any=YES; }
 if(any&&deviceChanged) deviceChanged();
}
void MTUnwatchDevices(void) {
 deviceChanged=nil;
 if(addedIterator) { IOObjectRelease(addedIterator); addedIterator=0; }
 if(removedIterator) { IOObjectRelease(removedIterator); removedIterator=0; }
 if(notificationPort) { IONotificationPortDestroy(notificationPort); notificationPort=NULL; }
}
void MTWatchDevices(void (^changed)(void)) {
 MTUnwatchDevices();
 notificationPort=IONotificationPortCreate(kIOMainPortDefault);
 if(!notificationPort) return;
 IONotificationPortSetDispatchQueue(notificationPort,dispatch_get_main_queue());
 IOServiceAddMatchingNotification(notificationPort,kIOFirstMatchNotification,IOServiceMatching("AppleMultitouchDevice"),drainDevices,NULL,&addedIterator);
 IOServiceAddMatchingNotification(notificationPort,kIOTerminatedNotification,IOServiceMatching("AppleMultitouchDevice"),drainDevices,NULL,&removedIterator);
 // Drain to arm both notifications; the caller performs the initial scan itself.
 drainDevices(NULL,addedIterator); drainDevices(NULL,removedIterator);
 deviceChanged=[changed copy];
}

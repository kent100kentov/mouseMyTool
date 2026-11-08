#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef struct { int32_t identity, state; float x, y; } MTContact;
typedef void (^MTFrameHandler)(uint64_t device, const MTContact * _Nullable contacts, int count, double time);
@interface MTBridge : NSObject
@property(nonatomic, copy, nullable) MTFrameHandler handler;
- (NSString *)diagnostics;
- (NSInteger)start;
- (void)stop;
@end
void MTWatchDevices(void (^changed)(void));
void MTUnwatchDevices(void);

NS_ASSUME_NONNULL_END

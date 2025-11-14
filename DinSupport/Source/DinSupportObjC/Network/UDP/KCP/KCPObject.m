//
//  KCPObject.m
//  KCPKit
//
//  Created by eki on 2020/7/16.
//  Copyright © 2020 eric3u. All rights reserved.
//

#import "ikcp.h"
#import "KCPObject.h"

@interface KCPObject ()

@property (nonatomic, assign) ikcpcb *kcp;
@property (nonatomic, assign) uint8_t *mtuBuffer;

/// 下次刷新的时间（毫秒）
@property (nonatomic, assign) int nextRefreshTime;
/// 用于kcp的计时（毫秒）
@property (nonatomic, assign) u_int32_t curClock;

/// 是否需要处理
@property (nonatomic, assign) BOOL processOn;
@property (nonatomic, strong) dispatch_queue_t kcpQueue;

@property (nonatomic, copy) KCPObjectOutputDataHandle outputDataHandle;

@end

@implementation KCPObject

+ (nonnull NSString*)convOf:(NSData *)data {
    IUINT32 conv = ikcp_getconv(data.bytes);
    NSString *convString = [NSString stringWithFormat:@"%u",conv];
    if (!convString) {
        convString = @"";
    }
    return convString;
}

- (void)dealloc {
    _processOn = NO;
    if (_kcp) {
        ikcp_release(_kcp);
        _kcp = NULL;
    }
    if (_mtuBuffer) {
        free(_mtuBuffer);
        _mtuBuffer = NULL;
    }
}

- (instancetype)initWithConvID:(UInt32)convID
                 outputDataHandle:(KCPObjectOutputDataHandle)outputDataHandle {
    self = [super init];
    if (self) {
        _convString = [NSString stringWithFormat:@"%u", (unsigned int)convID];
        NSString *queueName = [NSString stringWithFormat:@"com.dinsafer.ipc.kcpwork.%@",_convString];
        _kcpQueue = dispatch_queue_create([queueName UTF8String], 0);
        // 获取全局的高优先级队列
        dispatch_queue_t highPriorityQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        // 将自定义队列的目标队列设置为全局高优先级队列
        dispatch_set_target_queue(_kcpQueue, highPriorityQueue);
        _processOn = NO;

        _kcp = ikcp_create((IUINT32)convID, (__bridge void *)self);
        NSAssert(_kcp != NULL, @"can not create kcp");
        _kcp->rst_handle = kcp_rst;
        _kcp->output = kcp_output;
        ikcp_nodelay(_kcp, 1, 10, 2, 1);
        _kcp->rx_minrto = 10;
        ikcp_wndsize(_kcp, 1024, 1024);
        ikcp_setmtu(_kcp, 1350);
        self.outputDataHandle = outputDataHandle;
        _nextRefreshTime = 2; // 2ms
        _curClock = 0;
        
        _mtuBuffer = malloc(_kcp->mtu*1024);
        memset(_mtuBuffer, 0, _kcp->mtu*1024);
    }
    return self;
}

- (void)startReceiving {
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(_kcpQueue, ^{
        if (blockSelf) {
            blockSelf.processOn = YES;
            [blockSelf startCount];
        }
    });
}

- (void)stopReceiving {
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(_kcpQueue, ^{
        if (blockSelf) {
            blockSelf.processOn = NO;
        }
    });
}

- (void)startCount {
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_time_t nextTime = dispatch_time(DISPATCH_TIME_NOW, (ino64_t)(_nextRefreshTime * NSEC_PER_MSEC));
    dispatch_after(nextTime, blockSelf.kcpQueue, ^{
        if (blockSelf && blockSelf.processOn) {
                [blockSelf refreshKcp];
        }
    });
}

- (void)refreshKcp {
    [self update];
    // clock的时钟是纳秒，所以出来的时间需要转成秒
    int nextTime = ikcp_check(self.kcp, self.curClock) - self.curClock;
    self.curClock += self.nextRefreshTime;
    self.nextRefreshTime = (nextTime == 0) ? 2 : nextTime;
    // 至少10ms刷新一次
    if (self.nextRefreshTime > 7) {
        self.nextRefreshTime = 7;
    }
    // 从缓存获取数据
    NSData *recvHDData = [self recvData];
    if (recvHDData) {
        // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
        __block KCPObject *blockSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(kcp:didReceivedData:)]) {
                [blockSelf.delegate kcp:blockSelf didReceivedData:recvHDData];
            }
        });
    }
    [self startCount];
}

- (void)update {
    ikcp_update(_kcp, _curClock);
}

- (void)inputData:(NSData *)data {
    if (!_processOn) {
        return;
    }
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(_kcpQueue, ^{
        if (blockSelf.kcp) {
            ikcp_input(blockSelf.kcp, data.bytes, data.length);
        }
    });
}

- (void)sendData:(NSData *)data {
//    NSLog(@"KCPObject send data: %@ - with conv:%@\n", data, _convString);
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(_kcpQueue, ^{
        if (blockSelf.kcp) {
            ikcp_send(blockSelf.kcp, data.bytes, (int)data.length);
        }
    });
}

- (void)sendReset {
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(_kcpQueue, ^{
        if (blockSelf.kcp) {
            ikcp_reset_connection(blockSelf.kcp);
        }
    });
}

- (NSData *)recvData {
    int mtuSize = _kcp->mtu*1024;
    int recvSize = ikcp_recv(_kcp, (char *)_mtuBuffer, mtuSize);
    if (recvSize <= 0) {
        return nil;
    }
    NSData *data = [[NSData alloc] initWithBytes:_mtuBuffer length:recvSize];
    return data;
}

#pragma mark - Handler
- (int)handleKCPOutputWithData:(NSData *)data {
    if (self.outputDataHandle) {
        return self.outputDataHandle(data);
    }
    return -1;
}

- (void)resetNotify {
    // 使用__block来维持Self的存在，以免在queue执行过程中，Self在其他线程中被deinit
    __block KCPObject *blockSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (blockSelf.delegate && [blockSelf.delegate respondsToSelector:@selector(kcpDidReceivedResetRequest:)]) {
            [blockSelf.delegate kcpDidReceivedResetRequest:blockSelf];
        }
    });
}

#pragma mark - KCP Callback
int kcp_output(const char *buf, int len, struct IKCPCB *kcp, void *user) {
    @autoreleasepool {
        KCPObject *object = (__bridge KCPObject *)user;
        if (object) {
            NSData *data = [NSData dataWithBytes:buf length:len];
            return [object handleKCPOutputWithData:data];
        }
        return -1;
    }
}

int kcp_rst(struct IKCPCB *kcp, void *user) {
    @autoreleasepool {
        KCPObject *object = (__bridge KCPObject *)user;
        if (object) {
            [object resetNotify];
        }
        return -1;
    }
}

@end

# 一、NSTimer


```objc
- (instancetype)initWithFireDate:(NSDate *)date 
                        interval:(NSTimeInterval)ti 
                          target:(id)t 
                        selector:(SEL)s 
                        userInfo:(nullable id)ui 
                         repeats:(BOOL)rep
```

```objc
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti 
                        invocation:(NSInvocation *)invocation 
                           repeats:(BOOL)yesOrNo;
```

```objc
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti 
                            target:(id)aTarget 
                          selector:(SEL)aSelector 
                          userInfo:(nullable id)userInfo 
                           repeats:(BOOL)yesOrNo;
```
- TimerInterval: 执行之前等待的时间。比如设置成1.0，就代表1秒后执行方法
- target: 需要执行方法的对象。
- selector : 需要执行的方法
- repeats : 是否需要循环

>以上的方法用来创建定时器，但是创建完必须自己把其添加到RunLoop


```objc
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti 
                                 invocation:(NSInvocation *)invocation 
                                    repeats:(BOOL)yesOrNo;
```

```objc
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti 
                                     target:(id)aTarget 
                                   selector:(SEL)aSelector 
                                   userInfo:(nullable id)userInfo 
                                    repeats:(BOOL)yesOrNo;
```
>以上两个方法也是创建定时器的方法，但在创建的同时内部已经把定时器添加到主循环中,并且是RunLoop默认模式，因此会被滑动等时间影响。

例如：

```objc
    //初始化一个Invocation对象
    NSInvocation * invo = [NSInvocation invocationWithMethodSignature:[[self class] instanceMethodSignatureForSelector:@selector(init)]];
    [invo setTarget:self];
    [invo setSelector:@selector(timerAction)];
    NSTimer * timer = [NSTimer timerWithTimeInterval:1 invocation:invo repeats:YES];
    //加入主循环池中
    [[NSRunLoop mainRunLoop]addTimer:timer forMode:NSDefaultRunLoopMode];
    //开始循环
    [timer fire];
```

```objc
//创建定时器
NSTimer *timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
//添加到主循环
[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
```
释放定时器：

```objc
[timer invalidate];
timer = nil;
```
>用NSTimer来作为定时器会存在延迟的缺点。因为NSTimer也是做为一种资源添加到RunLoop中，所以其触发的时间等都与RunLoop相关。如果RunLoop正在进行连续性的计算，会延时触发NSTimer。

>在OS X v10.9以后为了尽量避免在NSTimer触发时间到了而去中断当前处理的任务，NSTimer新增了tolerance属性，让用户可以设置可以容忍的触发的时间范围。
# 二、CADisplayLink

```objc
//创建CADisplayLink
CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(MyAction)];
//添加到主循环
[displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
```
```objc
//结束一个CADisplayLink
[displayLink invalidate];
```
>CADisplayLink创建后也需要添加到RunLoop

属性：
- paused : 设置这个属性可以控制CADisplayLink是否暂停
- duration : 提供了每帧之间的时间，也就是屏幕每次刷新之间的的时间(为只读属性)
- frameInterval :调用的帧间隔， 默认值为1，屏幕每刷新一帧就调用，即1/60秒一次。如果设置为2，就会两帧调用一次，即1/30秒。

>* CADisplayLink这个定时器的频率和屏幕刷新率相同，因此适合在不停重绘界面的场合使用，比如自定义动画引擎或者视频播放的渲染。
>* iOS设备的屏幕刷新频率是固定的，CADisplayLink在正常情况下会在每次刷新结束都被调用，精确度相当高。但如果调用的方法比较耗时，超过了屏幕刷新周期，就会导致跳过若干次回调调用机会。

>如果CPU过于繁忙，无法保证屏幕60次/秒的刷新率，就会导致跳过若干次调用回调方法的机会，跳过次数取决CPU的忙碌程度。

# 三、dispatch_source

```objc
@property (nonatomic, strong) dispatch_source_t timer;
```

```objc
__block NSInteger count = 0;
 //创建队列
dispatch_queue_t queue = dispatch_get_main_queue();
//创建定时器
self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
//设置定时器时间
dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0);
uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
dispatch_source_set_timer(self.timer, start, interval, 0);
//设置回调
dispatch_source_set_event_handler(self.timer, ^{
    //重复执行的事件
    NSLog(@"-----%ld-----", count);
    count++;
    if (count == 5) {
         //停止定时器
         dispatch_source_cancel(self.timer);
         self.timer = nil;
     }
});
//启动定时器
dispatch_resume(self.timer);
```
>dispatch_source创建的定时器精确度最高，并且还可以放在子线程中，解决定时间跑在主线程上卡UI问题

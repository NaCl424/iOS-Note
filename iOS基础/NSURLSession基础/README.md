## 1.URL Session 类体系

```
1.NSURLSession ——会话类
2.NSURLSessionConfiguration ——会话配置
3.NSURLSessionTask——task抽象类
        - NSURLSessionDataTask——普通task类
            - NSRULSessionUploadTask——上传task类
        - NSURLSessionDownloadTask——下载task类
        - NSURLSessionStreamTask——流task类

代理
NSURLSessionDelegate
NSURLSessionTaskDelegate
NSURLSessionDataDelegate
NSURLSessionDownloadDelegate
NSURLSessionStreamDelegate

其他
NSURL
NSURLRequest
NSURLResponse
    - NSHTTPURLResponse
NSCachedURLResponse
```

## 2.NSURLSessionConfiguration
NSURLSession可以通过sharedSession创建，也可以通过NSURLSessionConfiguration来创建。

```objc
//使用静态的sharedSession方法，该类使用共享的会话，该会话使用全局的Cache，Cookie和证书
+ (NSURLSession *)sharedSession;  

//通过sessionWithConfiguration:方法创建对象，也就是创建对应配置的会话，与NSURLSessionConfiguration合作使用
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;  

//通过设置配置、代理、队列来创建会话对象
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id <NSURLSessionDelegate>)delegate delegateQueue:(NSOperationQueue *)queue;
```
NSURLSessionConfiguration其实是对NSURLSession的配置。
NSURLSession有以下三种模式，分别对应NSURLSessionConfiguration的三种创建模式：

```objc
+ (NSURLSessionConfiguration *)defaultSessionConfiguration;  
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration;  
+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier;
```

* 默认会话模式（default）：工作模式类似于原来的NSURLConnection，使用的是基于磁盘缓存的持久化策略，使用用户keychain中保存的证书进行认证授权。
* 瞬时会话模式（ephemeral）：该模式不使用磁盘保存任何数据。所有和会话相关的caches，证书，cookies等都被保存在RAM中，因此当程序使会话无效，这些缓存的数据就会被自动清空。（可以实现私密浏览）
* 后台会话模式（background）：该模式在后台完成上传和下载（在系统的一个单独的进程中执行），在创建Configuration对象的时候需要提供一个NSString类型的ID用于标识完成工作的后台会话。

NSURLSessionConfiguration各个属性的设置:

```objc
//如果在后台任务正在传输时程序退出，可以使用这个identifier在程序重新启动是创建一个新的configuration和session关联之前传输。
@property(readonly, copy) NSString  *identifier;

//默认为空，NSURLRequest附件的请求头。
//这个属性会给所有使用该configuration的session生成的tasks中的NSURLRequest添加额外的请求头。
//如果这里边添加的请求头跟NSURLRequest中重复了，侧优先使用NSURLRequest中的头
@property(copy) NSDictionary  *HTTPAdditionalHeaders;

//是否使用蜂窝网络，默认是yes.
@property BOOL allowsCellularAccess;

//给request指定每次接收数据超时间隔
//如果下一次接受新数据用时超过该值，则发送一个请求超时给该request。默认为60s
@property NSTimeInterval  timeoutIntervalForRequest;

//给指定resource设定一个超时时间，resource需要在时间到达之前完成
//默认是7天。 
@property NSTimeInterval  timeoutIntervalForResource;

//discretionary属性为YES时表示当程序在后台运作时由系统自己选择最佳的网络连接配置，该属性可以节省通过蜂窝连接的带宽。
//在使用后台传输数据的时候，建议使用discretionary属性，而不是allowsCellularAccess属性，因为它会把WiFi和电源可用性考虑在内。
@property (getter=isDiscretionary) BOOL discretionary;

//表示当后台传输结束时，是否启动app.这个属性只对 生效，其他configuration类型会自动忽略该值。默认值是YES。
@property BOOL sessionSendsLaunchEvents;

//是否启动通道，可以用于加快网络请求，默认是NO
@property BOOL HTTPShouldUsePipelining;

/===========储存的相关属性=============/

//存储cookie，清除存储，直接set为nil即可。
//对于默认和后台的session，使用sharedHTTPCookieStorage。
//对于短暂的session，cookie仅仅储存到内存，session失效时会自动清除。
@property(retain) NSHTTPCookieStorage  *HTTPCookieStorage;

//默认为yes,是否提供来自shareCookieStorge的cookie
//如果想要自己提供cookie，可以使用HTTPAdditionalHeaders来提供。
@property BOOL  HTTPShouldSetCookies;

//证书存储，如果不使用，可set为nil.
//默认和后台session，默认使用的sharedCredentialStorage.
//短暂的session使用一个私有存储在内存中。session失效会自动清除。
@property(retain) NSURLCredentialStorage *URLCredentialStorage;

//缓存NSURLRequest的response。
//默认的configuration，默认值的是sharedURLCache。
//后台的configuration，默认值是nil
//短暂的configuration，默认一个私有的cache于内存，session失效，cache自动清除。
@property(retain) NSURLCache  *URLCache;

//缓存策略，用于设置该会话中的Request的cachePolicy，如果Request有单独设置的话，以Request为准。
//默认值是NSURLRequestUseProtocolCachePolicy
@property NSURLRequestCachePolicy requestCachePolicy;
```

## 3.NSURLSessionTask
根据NSURLSession来创建task进行网络请求
* NSURLSessionDataTask,可以用来处理一般的网络请求，如 GET | POST 请求等。
* NSURLSessionUploadTask，用于处理上传请求。
* NSURLSessionDownloadTask，主要用于处理下载请求。

可以直接用异步回调的形式，也可以用代理的方式进行网络请求
#### 缓存:

```objc
typedef NS_ENUM(NSUInteger, NSURLRequestCachePolicy)
{
    //对特定的 URL 请求使用网络协议中实现的缓存逻辑。这是默认的策略。
    NSURLRequestUseProtocolCachePolicy = 0,

    //数据需要从原始地址加载。不使用现有缓存。
    NSURLRequestReloadIgnoringLocalCacheData = 1,

    // 不仅忽略本地缓存，同时也忽略代理服务器或其他中间介质目前已有的、协议允许的缓存。
    NSURLRequestReloadIgnoringLocalAndRemoteCacheData = 4, 

    NSURLRequestReloadIgnoringCacheData = NSURLRequestReloadIgnoringLocalCacheData,

    //无论缓存是否过期，先使用本地缓存数据。如果缓存中没有请求所对应的数据，那么从原始地址加载数据。
    NSURLRequestReturnCacheDataElseLoad = 2,

    //无论缓存是否过期，先使用本地缓存数据。如果缓存中没有请求所对应的数据，那么放弃从原始地址加载数据，请求视为失败（即：“离线”模式）。
    NSURLRequestReturnCacheDataDontLoad = 3,

    //从原始地址确认缓存数据的合法性后，缓存数据就可以使用，否则从原始地址加载。
    NSURLRequestReloadRevalidatingCacheData = 5, 
};
```

#### NSURLSessionDataTask

```objc
//这两个方法需要设置代理来接收数据
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;

//这两个方法在completionHandler来接收数据
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
```

```objc
#import "ViewController.h"

@interface ViewController () <NSURLSessionDelegate,NSURLSessionTaskDelegate>
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self sendRequest];
}
- (void)sendRequest{
    //创建请求
    NSURL *url = [NSURL URLWithString:@"http://httpbin.org/get"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    //设置request的缓存策略（决定该request是否要从缓存中获取）
    request.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    
    //创建配置（决定要不要将数据和响应缓存在磁盘）
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    //configuration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    
    //创建会话
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    //生成任务
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    //创建的task是停止状态，需要我们去启动
    [task resume];
}
//1.接收到服务器响应的时候调用
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    NSLog(@"接收响应");
    //必须告诉系统是否接收服务器返回的数据
    //默认是completionHandler(NSURLSessionResponseAllow)
    //可以再这边通过响应的statusCode来判断否接收服务器返回的数据
    completionHandler(NSURLSessionResponseAllow);
}
//2.接受到服务器返回数据的时候调用,可能被调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    NSLog(@"接收到数据");
    //一般在这边进行数据的拼接，在方法3才将完整数据回调
//    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}
//3.请求完成或者是失败的时候调用
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    NSLog(@"请求完成或者是失败");
    //在这边进行完整数据的解析，回调
}
//4.将要缓存响应的时候调用（必须是默认会话模式，GET请求才可以）
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler{
    //可以在这边更改是否缓存，默认的话是completionHandler(proposedResponse)
    //不想缓存的话可以设置completionHandler(nil)
    completionHandler(proposedResponse);
}
@end
```

```objc
NSURL *url = [NSURL URLWithString:@"http://www.connect.com/login"];
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
request.HTTPMethod = @"POST";
request.HTTPBody = [@"username=Tom&pwd=123" dataUsingEncoding:NSUTF8StringEncoding];

//使用全局的会话
NSURLSession *session = [NSURLSession sharedSession];
// 通过request初始化task
NSURLSessionTask *task = [session dataTaskWithRequest:request
                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) { 
    NSLog(@"%@", [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]);
 }];
//创建的task是停止状态，需要我们去启动
[task resume];
```

#### NSURLSessionUploadTask

```objc
/=========代理方式===========/
//通过文件url来上传
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;  
//通过文件data来上传
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;  
//通过文件流来上传
- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request;

/=========Block方式===========/
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;  
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
```

这三种上传方式分别针对什么应用场景呢？
* NSData：如果对象已经在内存里
* File：如果对象在磁盘上，这样做有助于降低内存使用
* Stream：通过流对象，你可以不用一次性将所有的流数据加载到内存中
不过使用Stream一定要实现URLSession:task:needNewBodyStream:，因为Session没办法在重新尝试发送Stream的时候找到数据源。

```objc
//上传图片
- (void)uploadRequest{
    //创建请求
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.freeimagehosting.net/upload.php"]];
    //如果是上传文字就是@"application/json"
    [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"text/html" forHTTPHeaderField:@"Accept"];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:20];
    NSData * imagedata = UIImageJPEGRepresentation([UIImage imageNamed:@"person"],1.0);
    
    //创建配置（决定要不要将数据和响应缓存在磁盘）
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    //创建会话
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    NSURLSessionUploadTask * uploadtask = [session uploadTaskWithRequest:request fromData:imagedata completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //发送完成的回调
        
    }];
    [uploadtask resume];
}
//发送数据过程中会执行(执行多次)
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    NSLog(@"发送数据中");
    //在这边监听发送的进度
    //progress = totalBytesSent/(float)totalBytesExpectedToSend
}
```

#### NSURLSessionDownloadTask

* 下载文件可以实现断点下载
* 内部已经完成了边接收数据边写入沙盒的操作（直接下载到磁盘）
* 支持BackgroundSession（后台下载）

使用NSURLSessionDownloadTask 下载文件的过程与前面差不多，需要注意的是文件下载文件之后会自动保存到一个临时目录(temp)，需要开发人员自己将此文件重新放到其他指定的目录中。 或者直接在内存里面显示, 默认异步的.NSURLSession 自动不会出现内存暴涨情况

```objc
/=========代理方式===========/
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;  
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url;  
//通过之前已经下载的数据来创建下载任务
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData;  

/=========Block方式===========/
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;  
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;  
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;
```

```objc
- (void)downloadRequest{
    //创建请求
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://httpbin.org/image/jpeg"]];
    
    //创建配置（决定要不要将数据和响应缓存在磁盘）
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    //创建会话
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    NSURLSessionDownloadTask * downloadtask = [session downloadTaskWithRequest:request];
    [downloadtask resume];
}

//1. downloadTask下载过程中会执行
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    NSLog(@"下载中...");
    NSLog(@"写入数据大小%lld，总写入数据大小%lld，总期望数据大小%lld",bytesWritten,totalBytesWritten,totalBytesExpectedToWrite);
    //监听下载的进度
}
//2.downloadTask下载完成的时候会执行
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    NSLog(@"下载完成");
       //该方法内部已经完成了边接收数据边写沙盒的操作，解决了内存飙升的问题
    //对数据进行使用，或者保存（默认存储到临时文件夹 tmp 中，需要剪切文件到 cache）
    
    //保存
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:downloadTask.response.suggestedFilename];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:filePath] error:nil];

    //使用
    NSData * data = [NSData dataWithContentsOfURL:location.filePathURL];
    UIImage * image = [UIImage imageWithData:data];
    UIImageWriteToSavedPhotosAlbum(image, nil,nil,nil);
}
//3.请求完成或者是失败的时候调用(Session层次的Task完成的事件)
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    NSLog(@"请求完成或者是失败");
}
```

断点续传:

```objc
// 使用这种方式取消下载可以得到将来用来恢复的数据,保存起来
[self.task cancelByProducingResumeData:^(NSData *resumeData) {
    self.resumeData = resumeData;
}];

// 由于下载失败导致的下载中断会进入此协议方法,也可以得到用来恢复的数据
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 保存恢复数据
    self.resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
}

// 恢复下载时接过保存的恢复数据
self.task = [self.session downloadTaskWithResumeData:self.resumeData];
// 启动任务
[self.task resume];
```

后台下载

使用后台会话进行下程序退出到后台也能正常下载完成,但是程序在后台UI无法更新,不能获取进度;这时,我们需要通过应用程序代理进行UI更新,原理如图:

![](./img/img1.png)

当NSURLSession在后台开启几个任务之后,如果其中有任务完成,系统就会会调用此APP的代理方法:```- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifiercompletionHandler:(void (^)(void))completionHandler```里进行完成的操作. 通常我们会保持此对象,直到最后一个任务完成; 
此时会重新通过会话标识(config中设置的)找到对应会话并调用NSURLSession的```-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession * )session```代理方法例进行UI的更新.并调用completionHandler通知系统已经完成所有操作。具体如下:

```objc
-(void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler{

    //backgroundSessionCompletionHandler是自定义的一个属性
    self.backgroundSessionCompletionHandler=completionHandler;   
}

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    //Other Operation....

    if (appDelegate.backgroundSessionCompletionHandler) {

        void (^completionHandler)() = appDelegate.backgroundSessionCompletionHandler;     
        appDelegate.backgroundSessionCompletionHandler = nil;        
        completionHandler();
    }
}
```

使用GCD进行一次发起多个请求，全部完成后进行统一处理

```objc
let group : dispatch_group_t = dispatch_group_create()
let queue : dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
dispatch_group_async(group, queue) { 
  dispatch_group_enter(group)
  //发起第一个请求
}

dispatch_group_async(group, queue) {
  dispatch_group_enter(group)
  //发起第二个请求
}

dispatch_group_notify(group, queue) {
  //全部完成后，进行统一处理
}

//每个请求完成时，调用dispatch_group_leave(group)
```

参考:</br>
https://www.jianshu.com/p/a8fc22afb739
http://blog.csdn.net/csdnhaoren13/article/details/50809506

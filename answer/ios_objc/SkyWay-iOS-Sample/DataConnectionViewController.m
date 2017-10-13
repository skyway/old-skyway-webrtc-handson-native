//
// DataConnectionViewController.m
// SkyWay-iOS-Sample
//

#import "DataConnectionViewController.h"

#import <SkyWay/SKWPeer.h>

#import "AppDelegate.h"
#import "PeersListViewController.h"


// Enter your APIkey and Domain
// Please check this page. >> https://skyway.io/ds/

typedef NS_ENUM(NSUInteger, ViewTag)
{
    TAG_ID = 1000,
    TAG_WEBRTC_ACTION,
    TAG_VIEW,
    TAG_LOG,
    TAG_EDIT_MESSAGE,
    TAG_SEND_DATA,
    TAG_IMG_VIEW,
    AS_DATA_TYPE,
};

typedef NS_ENUM(NSUInteger, DataType)
{
    DT_STRING,
    DT_NUMBER,
    DT_ARRAY,
    DT_DICTIONARY,
    DT_DATA,
};

@interface DataConnectionViewController ()
< UINavigationControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate, UIPopoverControllerDelegate >
{
    SKWPeer*				_peer;
    SKWDataConnection*	_data;
    
    NSString*			_id;
    BOOL				_bEstablished;
    NSMutableArray*      _listPeerIds;
    
    UITextField*        _editMessage;
}

@end

@implementation DataConnectionViewController


#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    _id = nil;
    
    _bEstablished = NO;
    _data = nil;
    

    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    if (nil != self.navigationController)
    {
        [self.navigationController setDelegate:self];
    }
    
    /////////////////////////////////////////////////////////////
    /////////////////////  3.1．サーバへ接続  /////////////////////
    ////////////////////////////////////////////////////////////
    
    //APIキー、ドメインを設定
    SKWPeerOption* option = [[SKWPeerOption alloc] init];
    option.key = @"";
    option.domain = @"";
    
    // Peerオブジェクトのインスタンスを生成
    _peer	= [[SKWPeer alloc] initWithId:nil options:option];
    
    
    ///////////////////////////////////////////////////////////////
    /////////////////////  3.2．接続成功・失敗  /////////////////////
    //////////////////////////////////////////////////////////////
    
    
    //接続エラー時の処理：コールバックを登録（ERROR)
    [_peer on:SKW_PEER_EVENT_ERROR callback:^(NSObject* obj)
     {
         SKWPeerError* error = (SKWPeerError*)obj;
         NSLog(@"%@",error);
     }];
    
    
    
    //接続成功時の処理：コールバックを登録（OPEN)
    [_peer on:SKW_PEER_EVENT_OPEN callback:^(NSObject* obj)
     {
         _id = (NSString *)obj;
         dispatch_async(dispatch_get_main_queue(), ^{
             UILabel* lbl = (UILabel*)[self.view viewWithTag:TAG_ID];
             [lbl setText:[NSString stringWithFormat:@"your ID: \n%@", _id]];
         });
     }];
    
    
    ////////////////////////////////////////////////////////////
    /////////////////////  3.3.相手から着信  /////////////////////
    ////////////////////////////////////////////////////////////
    
    
    [_peer on:SKW_PEER_EVENT_CONNECTION callback:^(NSObject* obj)
     {
        _data = (SKWDataConnection *)obj;
        [self setDataCallback:_data];
         _bEstablished = YES;
         [self updateUI];
     }];
    
    
    [self setupUI];
    
}

//データチャネルのコールバック処理
- (void)setDataCallback:(SKWDataConnection *)data
{
    //コールバックを登録(チャンネルOPEN)
    [data on:SKW_DATACONNECTION_EVENT_OPEN callback:^(NSObject* obj)
     {
         [self appendLogWithHead:@"system" value:@"DataConnection opened."];
         _bEstablished = YES;
         [self updateUI];
     }];

    // コールバックを登録（データを受信)
    [data on:SKW_DATACONNECTION_EVENT_DATA callback:^(NSObject* obj)
     {
         NSString* strValue = (NSString*)obj;
         [self appendLogWithHead:@"Partner" value:strValue];
         
     }];

    // コールバックを登録(チャンネルOCLOSE)
    [data on:SKW_DATACONNECTION_EVENT_CLOSE callback:^(NSObject* obj)
     {
         _data = nil;
         _bEstablished = NO;
         [self updateUI];
         [self appendLogWithHead:@"system" value:@"DataConnection closed."];
     }];
}




    ///////////////////////////////////////////////////////////////////
    /////////////////////  3.4.　相手へのデータ発信　/////////////////////
    //////////////////////////////////////////////////////////////////


//接続相手を選択する
- (void)getPeerList
{
    if ((nil == _peer) || (nil == _id) || (0 == _id.length)){
        return;
    }
    
    [_peer listAllPeers:^(NSArray* peers)
     {
         _listPeerIds = [[NSMutableArray alloc] init];
         
         for (NSString* strValue in peers)
         {
             if (NSOrderedSame == [_id caseInsensitiveCompare:strValue])
             {
                 continue;
             }
             
             [_listPeerIds addObject:strValue];
         }
         if((nil != _listPeerIds) && (0< [_listPeerIds count]))
         {
             [self showPeerListDialog];
         }
         
     }];
}


//データチャンネルを開く
- (void)connect:(NSString *)strDestId
{
    // connect option
    SKWConnectOption* option = [[SKWConnectOption alloc] init];
    option.label = @"chat";
    option.metadata = @"{'message': 'hi'}";
    option.serialization = SKW_SERIALIZATION_BINARY;
    
    // connect
    _data = [_peer connectWithId:strDestId options:option];
    [self setDataCallback:_data];
    
}

//データチャンネルを閉じる
- (void)close
{
    if (NO == _bEstablished)
    {
        return;
    }
    _bEstablished = NO;
    
    if (nil != _data)
    {
        [_data close];
    }
}


//テキストデータを送信する
- (void)send:(NSString *)data
{
    BOOL bResult = [_data send:data];
    
    if (bResult == true) {
        [self appendLogWithHead:@"You" value:data];
    }
}

- (void)dealloc
{
    _id = nil;
    _data = nil;
    _peer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateUI];
}


#pragma mark - Public method





-(void)showPeerListDialog
{
    PeersListViewController* vc = [[PeersListViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.items = [NSArray arrayWithArray:_listPeerIds];
    vc.callback = self;
    
    UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:vc];
    
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       [self presentViewController:nc animated:YES completion:nil];
                   });
}



#pragma mark - Send Data


- (void)updateUI
{
    dispatch_async(dispatch_get_main_queue(), ^
       {
           NSString* strTitle = @"---";
           
           UIButton* btn = (UIButton *)[self.view viewWithTag:TAG_WEBRTC_ACTION];
           if (nil != btn)
           {
               if (NO == _bEstablished)
               {
                   strTitle = @"Connect";
               }
               else
               {
                   strTitle = @"Disconnect";
               }
               
               [btn setTitle:strTitle forState:UIControlStateNormal];
           }
           
           //update ID Label
           UILabel* lbl = (UILabel*)[self.view viewWithTag:TAG_ID];
           if (nil == _id)
           {
               [lbl setText:@"your ID: "];
           }
           else
           {
               [lbl setText:[NSString stringWithFormat:@"your ID: \n%@", _id]];
           }
           
           
           //send button
           UIButton* sendbtn = (UIButton *)[self.view viewWithTag:TAG_SEND_DATA];
           if (nil != sendbtn)
           {
               [sendbtn setEnabled:_bEstablished];
           }
       });
}


- (void)appendLogWithMessage:(NSString *)strMessage
{
    UITextView* tvLog = (UITextView *)[self.view viewWithTag:TAG_LOG];
    
    NSRange rng = NSMakeRange(tvLog.text.length + 1, 0);
    [tvLog setSelectedRange:rng];
    
    [tvLog replaceRange:tvLog.selectedTextRange withText:strMessage];
    
    rng = NSMakeRange(tvLog.text.length + 1, 0);
    [tvLog scrollRangeToVisible:rng];
}


- (void)appendLogWithHead:(NSString *)strHeader value:(NSString *)strValue
{
    if (0 == strValue.length)
    {
        return;
    }
    
    NSMutableString* mstrValue = [[NSMutableString alloc] init];
    
    if (nil != strHeader)
    {
        [mstrValue appendString:@"["];
        [mstrValue appendString:strHeader];
        [mstrValue appendString:@"] "];
    }
    
    if (32000 < strValue.length)
    {
        NSRange rng = NSMakeRange(0, 32);
        [mstrValue appendString:[strValue substringWithRange:rng]];
        [mstrValue appendString:@"..."];
        rng = NSMakeRange(strValue.length - 32, 32);
        [mstrValue appendString:[strValue substringWithRange:rng]];
    }
    else
    {
        [mstrValue appendString:strValue];
    }
    
    [mstrValue appendString:@"\n"];
    
    [self performSelectorOnMainThread:@selector(appendLogWithMessage:) withObject:mstrValue waitUntilDone:YES];
}



#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (UINavigationControllerOperationPop == operation)
    {
        if (YES == [fromVC isKindOfClass:[DataConnectionViewController class]])
        {
            // Back
            [self performSelectorOnMainThread:@selector(clearViewController) withObject:nil waitUntilDone:NO];
            
            [navigationController setDelegate:nil];
        }
    }
    
    return nil;
}

- (void)clearViewController
{
    self.navigationItem.rightBarButtonItem = nil;
    
    [SKWNavigator terminate];
    
    if (nil != _peer)
    {
        [_peer destroy];
    }
}



- (void)setupUI
{
    if (nil != self.navigationItem)
    {
        NSString* strTitle = @"DataConnection";
        [self.navigationItem setTitle:strTitle];
    }
    
    CGRect rcScreen = self.view.bounds;

    CGFloat fValue = [UIApplication sharedApplication].statusBarFrame.size.height;
    rcScreen.origin.y = fValue;
    fValue = self.navigationController.navigationBar.frame.size.height;
    rcScreen.origin.y += fValue;

    UIFont* fnt = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    CGRect rcDesign = rcScreen;
    rcDesign.size.width = (rcScreen.size.width / 3.0f) * 2.0f;
    rcDesign.size.height = fnt.lineHeight * 3.0f;
    
    // IDラベル用CGRect
    CGRect rcId = CGRectInset(rcDesign, 2.0f, 2.0f);
    
    //ActionButton用CGRect
    rcDesign.origin.x	+= rcDesign.size.width;
    rcDesign.size.width = rcScreen.size.width - rcDesign.origin.x;
    
    CGRect rcActionButton = CGRectInset(rcDesign, 2.0f, 2.0f);
    
    //テキストフィールド用CGRect
    rcDesign.origin.x = 0.0f;
    rcDesign.size.width = (rcScreen.size.width / 3.0f) * 2.0f;
    rcDesign.origin.y = rcId.origin.y + rcId.size.height + 4.0f;
    
    CGRect rcEditMessage = CGRectInset(rcDesign, 2.0f, 2.0f);
    
    //データ送信ボタン用CGRect
    rcDesign.origin.x	+= rcDesign.size.width;
    rcDesign.size.width = rcScreen.size.width - rcDesign.origin.x;
    
    CGRect rcSendData = CGRectInset(rcDesign, 2.0f, 2.0f);
    
    
    //ログ送信用CGRect
    CGRect rcLog = CGRectZero;
    rcLog.origin.y = rcDesign.origin.y + rcDesign.size.height + 4.0f;
    rcLog.size.width = rcScreen.size.width;
    rcLog.size.height = rcScreen.size.height - rcLog.origin.y - 100.0f;
    
    
    
    
    //IDラベル
    UILabel* lblId = [[UILabel alloc] initWithFrame:rcId];
    [lblId setTag:TAG_ID];
    [lblId setFont:fnt];
    [lblId setTextAlignment:NSTextAlignmentCenter];
    lblId.numberOfLines = 2;
    [lblId setText:@"your ID:\n ---"];
    [lblId setBackgroundColor:[UIColor whiteColor]];
    
    [self.view addSubview:lblId];
    
    
    // アクションボタン
    UIButton* btnCall = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnCall setTag:TAG_WEBRTC_ACTION];
    [btnCall setFrame:rcActionButton];
    [btnCall setTitle:@"Connect to" forState:UIControlStateNormal];
    [btnCall setBackgroundColor:[UIColor lightGrayColor]];
    [btnCall addTarget:self action:@selector(pushCallButton:) forControlEvents:UIControlEventTouchUpInside];
    [btnCall setEnabled:YES];
    
    [self.view addSubview:btnCall];
    
    
    //テキスト入力フィールド
    _editMessage = [[UITextField alloc]initWithFrame:rcEditMessage];
    [_editMessage setTag:TAG_EDIT_MESSAGE];
    [_editMessage.layer setBorderWidth:0.5f];
    
    
    [self.view addSubview:_editMessage];
    
    
    
    //データ送信ボタン
    UIButton* btnSendData = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnSendData setTag:TAG_SEND_DATA];
    [btnSendData setFrame:rcSendData];
    [btnSendData setTitle:@"Send" forState:UIControlStateNormal];
    [btnSendData setBackgroundColor:[UIColor lightGrayColor]];
    [btnSendData addTarget:self action:@selector(pushSendButton:) forControlEvents:UIControlEventTouchUpInside];
    [btnSendData setEnabled:NO];
    
    [self.view addSubview:btnSendData];
    
    //送信Log
    UITextView* tvLog = [[UITextView alloc] initWithFrame:rcLog];
    [tvLog setTag:TAG_LOG];
    [tvLog setFrame:rcLog];
    [tvLog setBackgroundColor:[UIColor whiteColor]];
    tvLog.layer.borderWidth = 1;
    tvLog.layer.borderColor = [[UIColor orangeColor] CGColor];
    [tvLog setEditable:NO];
    
    [self.view addSubview:tvLog];
    
    
    [self updateUI];
}

- (void)pushCallButton:(NSObject *)sender
{
    UIButton* btn = (UIButton *)sender;
    
    if (TAG_WEBRTC_ACTION == btn.tag)
    {
        if (nil == _data)
        {
            // Listing all peers
            [self getPeerList];
        }
        else
        {
            // Closing chat
            [self performSelectorInBackground:@selector(close) withObject:nil];
        }
    }
}

- (void)pushSendButton:(NSObject *)sender
{
    UIButton* btn = (UIButton *)sender;
    
    if (TAG_SEND_DATA == btn.tag)
    {
        NSString *data =_editMessage.text;
        [self send:data];
        _editMessage.text = @"";
    }
}



@end

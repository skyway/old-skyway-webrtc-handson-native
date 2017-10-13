//
// MediaConnectionViewController.m
// SkyWay-iOS-Sample
//

#import "MediaConnectionViewController.h"

#import <AVFoundation/AVFoundation.h>

#import <SkyWay/SKWPeer.h>

#import "AppDelegate.h"
#import "PeersListViewController.h"


// Enter your APIkey and Domain
// Please check this page. >> https://skyway.io/ds/


typedef NS_ENUM(NSUInteger, ViewTag)
{
	TAG_ID = 1000,
	TAG_WEBRTC_ACTION,
	TAG_REMOTE_VIDEO,
	TAG_LOCAL_VIDEO,
};

typedef NS_ENUM(NSUInteger, AlertType)
{
	ALERT_ERROR,
	ALERT_CALLING,
};

@interface MediaConnectionViewController ()
< UINavigationControllerDelegate, UIAlertViewDelegate>
{
	SKWPeer*			_peer;
	SKWMediaStream*		_msLocal;
	SKWMediaStream*		_msRemote;
	SKWMediaConnection*	_mediaConnection;
	
	NSString*			_id;
    BOOL                _bEstablished;
    NSMutableArray*      _listPeerIds;
}

@end

@implementation MediaConnectionViewController


#pragma mark - Lifecycle




- (void)viewDidLoad
{
	[super viewDidLoad];
	_id = nil;
    _bEstablished = NO;
	
	[self.view setBackgroundColor:[UIColor whiteColor]];
    [self setupUI];
	
	if (nil != self.navigationController)
	{
		[self.navigationController setDelegate:self];
	}
    
    
    /////////////////////////////////////////////////////////////
    /////////////////////  2.1．サーバへ接続  /////////////////////
    ////////////////////////////////////////////////////////////
    
    //APIキー、ドメインを設定
    SKWPeerOption* option = [[SKWPeerOption alloc] init];
    option.key = @"";
    option.domain = @"";
    
    // Peerオブジェクトのインスタンスを生成
    _peer	= [[SKWPeer alloc] initWithOptions:option];
    
    
    ///////////////////////////////////////////////////////////////
    /////////////////////  2.2．接続成功・失敗  /////////////////////
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
    
    ///////////////////////////////////////////////////////////////
    /////////////////////  2.3．メディアの取得  /////////////////////
    //////////////////////////////////////////////////////////////
    
    //メディアを取得
    [SKWNavigator initialize:_peer];
    SKWMediaConstraints* constraints = [[SKWMediaConstraints alloc] init];
    _msLocal = [SKWNavigator getUserMedia:constraints];


    //ローカルビデオメディアをセット
    SKWVideo* localVideoView = [self.view viewWithTag:TAG_LOCAL_VIDEO];
    [_msLocal addVideoRenderer:localVideoView track:0];

    
    
    ////////////////////////////////////////////////////////////
    /////////////////////  2.4.相手から着信  /////////////////////
    ////////////////////////////////////////////////////////////
    
    //コールバックを登録（CALL)
    [_peer on:SKW_PEER_EVENT_CALL callback:^(NSObject* obj)
     {
         _mediaConnection = (SKWMediaConnection *)obj;
         [_mediaConnection answer:_msLocal];
         [self setMediaCallbacks:_mediaConnection];
         _bEstablished = YES;
         [self updateUI];
     }];

    }


- (void)setMediaCallbacks:(SKWMediaConnection *)media
{

    // コールバックを登録（Stream）
    [media on:SKW_MEDIACONNECTION_EVENT_STREAM callback:^(NSObject* obj)
     {
         _msRemote = (SKWMediaStream *)obj;
         
         dispatch_async(dispatch_get_main_queue(), ^
                        {
                            SKWVideo* remoteVideoView = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
                            [remoteVideoView setHidden:NO];
                            [_msRemote addVideoRenderer:remoteVideoView track:0];
                        });
     }];
    
    // コールバックを登録（Close）
    [media on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:^(NSObject* obj)
     {
        
         dispatch_async(dispatch_get_main_queue(), ^{
             SKWVideo* remoteVideoView  = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
             [_msRemote removeVideoRenderer:remoteVideoView track:0];
             _msRemote = nil;
             _mediaConnection = nil;
             _bEstablished = NO;
             [remoteVideoView setHidden:YES];
         });
         
         [self updateUI];
         
     }];
    
}

    ///////////////////////////////////////////////////////////////////
    /////////////////////  2.5.　相手へのビデオ発信　/////////////////////
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

- (void)call:(NSString *)strDestId
{
    SKWCallOption *option = [[SKWCallOption alloc]init];
    _mediaConnection = [_peer callWithId:strDestId stream:_msLocal options:option];
    
    if(_mediaConnection != nil){
        [self setMediaCallbacks:_mediaConnection];
        _bEstablished = YES;
    }
    
    [self updateUI];
    
}


//ビデオ通話を終了する
- (void)closeChat
{
    if (nil != _mediaConnection)
    {
        if (nil != _msRemote)
        {
            SKWVideo* video = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
            if (nil != video)
            {
                [_msRemote removeVideoRenderer:video track:0];
            }
            
            [_msRemote close];
            
            _msRemote = nil;
        }
        
        [_mediaConnection close];
    }
}


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


    //////////////////////////////////////////////////////////////////
    /////////////////////  2.6.　UIのセットアップ  /////////////////////
    /////////////////////////////////////////////////////////////////


//UIのセットアップ
- (void)setupUI
{
    //Navigation Bar
    if ((nil != self.navigationItem) && (nil == self.navigationItem.title))
    {
        [self.navigationItem setTitle:@"MediaConnection"];
    }
    
    CGRect rcScreen = self.view.bounds;
    
    
    
    //ローカルビデオ用のView
    CGRect rcLocal = CGRectZero;
    rcLocal.size.width = rcScreen.size.height / 5.0f;
    rcLocal.size.height = rcLocal.size.width;
    
    rcLocal.origin.x = rcScreen.size.width - rcLocal.size.width - 8.0f;
    rcLocal.origin.y = rcScreen.size.height - rcLocal.size.height - 8.0f;
    rcLocal.origin.y -= self.navigationController.toolbar.frame.size.height;
    
    //Local SKWVideo
    SKWVideo* vwLocal = [[SKWVideo alloc] initWithFrame:rcLocal];
    [vwLocal setTag:TAG_LOCAL_VIDEO];
    [self.view addSubview:vwLocal];
    
    
    
    //リモートビデオ用のView
    CGRect rcRemote = CGRectZero;
    rcRemote.size.width = rcScreen.size.width;
    rcRemote.size.height = rcRemote.size.width;
    
    rcRemote.origin.x = (rcScreen.size.width - rcRemote.size.width) / 2.0f;
    rcRemote.origin.y = (rcScreen.size.height - rcRemote.size.height) / 2.0f;
    rcRemote.origin.y -= 8.0f;
    
    //Remote SKWVideo
    SKWVideo* vwRemote = [[SKWVideo alloc] initWithFrame:rcRemote];
    [vwRemote setTag:TAG_REMOTE_VIDEO];
    [vwRemote setUserInteractionEnabled:NO];
    [vwRemote setHidden:YES];
    [self.view addSubview:vwRemote];
    
    
    // Peer ID View
    UIFont* fnt = [UIFont systemFontOfSize:[UIFont labelFontSize]];
    
    CGRect rcId = rcScreen;
    rcId.origin.y = self.navigationController.navigationBar.bounds.size.height+[[UIApplication sharedApplication] statusBarFrame].size.height;
    rcId.size.width = (rcScreen.size.width / 3.0f) * 2.0f;
    rcId.size.height = fnt.lineHeight * 2.0f;
    
    UILabel* lblId = [[UILabel alloc] initWithFrame:rcId];
    [lblId setTag:TAG_ID];
    [lblId setFont:fnt];
    [lblId setTextAlignment:NSTextAlignmentCenter];
    lblId.numberOfLines = 2;
    [lblId setText:@"your ID:\n ---"];
    [lblId setBackgroundColor:[UIColor whiteColor]];
    
    [self.view addSubview:lblId];
    
    // Callボタン
    CGRect rcCall = rcId;
    rcCall.origin.x	= rcId.origin.x + rcId.size.width;
    rcCall.size.width = (rcScreen.size.width / 3.0f) * 1.0f;
    rcCall.size.height = fnt.lineHeight * 2.0f;
    UIButton* btnCall = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnCall setTag:TAG_WEBRTC_ACTION];
    [btnCall setFrame:rcCall];
    [btnCall setTitle:@"Call" forState:UIControlStateNormal];
    [btnCall setBackgroundColor:[UIColor lightGrayColor]];
    [btnCall addTarget:self action:@selector(pushCallButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btnCall];
}



//UIの更新
-(void)updateUI{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //CALLボタンのアップデート
        UIButton* btn = (UIButton *)[self.view viewWithTag:TAG_WEBRTC_ACTION];
        if (NO == _bEstablished)
        {
            [btn setTitle:@"Call" forState:UIControlStateNormal];
        }
        else
        {
            [btn setTitle:@"Hang up" forState:UIControlStateNormal];
        }
        
        
        //IDラベルのアップデート
        UILabel* lbl = (UILabel*)[self.view viewWithTag:TAG_ID];
        if (nil == _id)
        {
            [lbl setText:@"your ID: "];
        }
        else
        {
            [lbl setText:[NSString stringWithFormat:@"your ID: \n%@", _id]];
        }
        
    });
}

#pragma mark - UIButtonActionDelegate

- (void)pushCallButton:(NSObject *)sender
{
    UIButton* btn = (UIButton *)sender;
    
    if (TAG_WEBRTC_ACTION == btn.tag)
    {
        if (nil == _mediaConnection)
        {
            // Listing all peers
            [self getPeerList];
        }
        else
        {
            // Closing chat
            [self performSelectorInBackground:@selector(closeChat) withObject:nil];
        }
    }
    
}




//////////////////////////////////////////////////////////////
/////////////////////  ハンズオンここまで  /////////////////////
////////////////////////////////////////////////////////////



- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	
	[self updateUI];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
	
	[super viewDidDisappear:animated];
}

- (void)dealloc
{
    _msLocal = nil;
	_msRemote = nil;
	
	_id = nil;
	
	_mediaConnection = nil;
	_peer = nil;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


#pragma mark - Public method




- (void)clearMediaCallbacks:(SKWMediaConnection *)media
{
	if (nil == media)
	{
		return;
	}
	
	[media on:SKW_MEDIACONNECTION_EVENT_STREAM callback:nil];
	[media on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:nil];
	[media on:SKW_MEDIACONNECTION_EVENT_ERROR callback:nil];
}


#pragma mark - Utility

- (void)clearViewController
{
	if (nil != _mediaConnection)
	{
		[self clearMediaCallbacks:_mediaConnection];
	}
	
	[self closeChat];
	
	if (nil != _msLocal)
	{
		[_msLocal close];
		_msLocal = nil;
	}
	
	if (nil != _peer)
	{
		//[self clearCallbacks:_peer];
	}
	
	for (UIView* vw in self.view.subviews)
	{
		if (YES == [vw isKindOfClass:[UIButton class]])
		{
			UIButton* btn = (UIButton *)vw;
			[btn removeTarget:self action:@selector(pushCallButton:) forControlEvents:UIControlEventTouchUpInside];
		}

		[vw removeFromSuperview];
	}
	
	self.navigationItem.rightBarButtonItem = nil;

	[SKWNavigator terminate];
	
	if (nil != _peer)
	{
		[_peer destroy];
	}
}



- (void)unsetRemoteView
{
	if (NO == _bEstablished)
	{
		return;
	}
	
	_bEstablished = NO;
	
	SKWVideo* vwRemote = (SKWVideo *)[self.view viewWithTag:TAG_REMOTE_VIDEO];
	
	if (nil != _msRemote)
	{
		if (nil != vwRemote)
		{
            [_msRemote removeVideoRenderer:vwRemote track:0];
		}
		
		[_msRemote close];
		
		_msRemote = nil;
	}
	
	if (nil != vwRemote)
	{
		dispatch_async(dispatch_get_main_queue(), ^
					   {
						   [vwRemote setUserInteractionEnabled:NO];
						   [vwRemote setHidden:YES];
					   });
	}
	
	[self updateUI];
}


#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
	if (UINavigationControllerOperationPop == operation)
	{
		if (YES == [fromVC isKindOfClass:[MediaConnectionViewController class]])
		{
			[self performSelectorOnMainThread:@selector(clearViewController) withObject:nil waitUntilDone:NO];
			
			[navigationController setDelegate:nil];
		}
	}
	
	return nil;
}







@end

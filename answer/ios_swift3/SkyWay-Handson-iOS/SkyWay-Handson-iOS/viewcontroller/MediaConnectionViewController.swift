//
//  MediaConnectionViewController.swift
//  SkyWay-Handson-iOS
//
//  Created by 羽田 健太郎 on 2017/08/09.
//  Copyright © 2017年  . All rights reserved.
//

import UIKit

class MediaConnectionViewController: UIViewController {

    fileprivate var _peer: SKWPeer?
    fileprivate var _msLocal: SKWMediaStream?
    fileprivate var _msRemote: SKWMediaStream?
    fileprivate var _mediaConnection: SKWMediaConnection?
    fileprivate var _id: String? = nil
    fileprivate var _bEstablished: Bool = false
    fileprivate var _listPeerIds: Array<String> = []
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var remoteVideoView: SKWVideo!
    @IBOutlet weak var localVideoView: SKWVideo!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: 2.1．サーバへ接続
        
        //APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init();
        option.key = kAPIKey
        option.domain = kAPIDomain
        
        // Peerオブジェクトのインスタンスを生成
        _peer = SKWPeer(options: option)
        
        
        // MARK: 2.2．接続成功・失敗
        
        //コールバックを登録（ERROR)
        // MARK: PEER_EVENT_ERROR
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_ERROR,callback:{ (obj) -> Void in
            if let error:SKWPeerError = obj as? SKWPeerError{
                print("\(error)")
            }
        })
        
        // コールバックを登録(OPEN)
        // MARK: PEER_EVENT_OPEN
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_OPEN,callback:{ (obj) -> Void in
            if let peerId = obj as? String{
                self._id = peerId
                DispatchQueue.main.async {
                    self.idLabel.text = "your ID: \(peerId)"
                }
            }
        })
        
        // MARK: 2.3．メディアの取得
        
        //メディアを取得
        SKWNavigator.initialize(_peer!);
        let constraints:SKWMediaConstraints = SKWMediaConstraints()
        _msLocal = SKWNavigator.getUserMedia(constraints) as SKWMediaStream?
        
        //ローカルビデオメディアをセット
        guard let msLocal = _msLocal else{
            return
        }
        msLocal.addVideoRenderer(localVideoView, track: 0)
        
        
        // MARK: 2.4.相手から着信
        
        //コールバックを登録（CALL)
        // MARK: PEER_EVENT_CALL
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_CALL, callback: { (obj) -> Void in
            self._mediaConnection = obj as? SKWMediaConnection
            self._mediaConnection?.answer(self._msLocal);
            self._bEstablished = true
            self.updateUI()
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: Manage Media Connection

extension MediaConnectionViewController{
    func setMediaCallbacks(media:SKWMediaConnection){
        
        //コールバックを登録（Stream）
        // MARK: MEDIACONNECTION_EVENT_STREAM
        media.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_STREAM, callback: { (obj) -> Void in
            if let msStream = obj as? SKWMediaStream{
                self._msRemote = msStream
                if self._msRemote == nil{
                        return
                }
                DispatchQueue.main.async {
                    self.remoteVideoView.isHidden = false
                    self._msRemote?.addVideoRenderer(self.remoteVideoView, track: 0)
                }
            }
        })
        
        //コールバックを登録（Close）
        // MARK: MEDIACONNECTION_EVENT_CLOSE
        media.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_CLOSE, callback: { (obj) -> Void in
            if let msStream = obj as? SKWMediaStream{
                self._msRemote = msStream
                DispatchQueue.main.async {
                    self._msRemote?.removeVideoRenderer(self.remoteVideoView, track: 0)
                    self._msRemote = nil
                    self._mediaConnection = nil
                    self._bEstablished = false
                    self.remoteVideoView.isHidden = true
                }
                self.updateUI()
            }
        })
    }
}

// MARK: 2.5.　相手へのビデオ発信
extension MediaConnectionViewController{
    
    func getPeerList(){
        if let peer = self._peer, let myPeerId = self._id, myPeerId.characters.count != 0{
            peer.listAllPeers({ (peers) -> Void in
                if let connectedPeerIds = peers as? [String]{
                    self._listPeerIds = connectedPeerIds.filter({ (connectedPeerId) -> Bool in
                        return connectedPeerId != myPeerId
                    })
                    if self._listPeerIds.count > 0{
                        self.showPeerDialog()
                    }else{
                        let alert: UIAlertController = UIAlertController(title: "No connected peerIds", message: nil, preferredStyle:  .alert)
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
                        alert.addAction(cancelAction)
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            })
        }
    }
    
    //ビデオ通話を開始する
    func call(strDestId: String) {
        let option = SKWCallOption()
        if let connection = _peer?.call(withId: strDestId, stream: _msLocal, options: option){
            _mediaConnection = connection
            self.setMediaCallbacks(media: connection)
            _bEstablished = true
        }
        self.updateUI()
    }
    
    //ビデオ通話を終了する
    func closeChat(){
        if let _ = _mediaConnection, let _ = _msRemote{
            guard let msRemote = self._msRemote else{
                return
            }
            self._msRemote?.removeVideoRenderer(self.remoteVideoView, track: 0)
            msRemote.close()
            self._msRemote = nil
            _mediaConnection?.close()
        }
    }
    
    func showPeerDialog(){
        let alert: UIAlertController = UIAlertController(title: "Select Call PeerID", message: nil, preferredStyle:  .alert)
        for peerId in _listPeerIds{
            let action = UIAlertAction(title: peerId, style: .default) { _ in
                self.call(strDestId: peerId)
            }
            alert.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }

}

// MARK: 2.6.　UIのセットアップ

extension MediaConnectionViewController{
       
    @IBAction func pushCallButton(sender: AnyObject) {
        
        if self._mediaConnection == nil {
            self.getPeerList()
        }else{
            self.closeChat()
        }
    }
    
    
    func updateUI(){
        DispatchQueue.main.async {
        
            //CALLボタンのアップデート
            if self._bEstablished == false{
                self.callButton.setTitle("CALL", for: UIControlState.normal)
            }else{
                self.callButton.setTitle("HangUp", for: UIControlState.normal)
            }
            
            //IDラベルのアップデート
            if self._id == nil{
                self.idLabel.text = "your Id:"
            }else{
                self.idLabel.text = "your Id:"+self._id! as String
            }
        }
    }
}

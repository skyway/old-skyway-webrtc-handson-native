//
//  DataConnectionViewController.swift
//  SkyWay-Handson-iOS
//
//  Created by 羽田 健太郎 on 2017/08/09.
//  Copyright © 2017年 羽田 健太郎. All rights reserved.
//

import UIKit

class DataConnectionViewController: UIViewController {

    fileprivate var _peer: SKWPeer?
    fileprivate var _data: SKWDataConnection?
    fileprivate var _id: String? = nil
    fileprivate var _bEstablished: Bool = false
    fileprivate var _listPeerIds: Array<String> = []
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var callButton: UIButton!
    
    @IBOutlet weak var sendButton: UIButton!
    
    
    @IBOutlet weak var editMessageTextField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: 3.1．サーバへ接続
        
        //APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init();
        option.key = kAPIKey
        option.domain = kAPIDomain
        
        // Peerオブジェクトのインスタンスを生成
        _peer = SKWPeer(options: option)
        
        
        // MARK: 3.2．接続成功・失敗
        // MARK: PEER_EVENT_ERROR
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_ERROR, callback:{ (obj) -> Void in
            if let error = obj as? SKWPeerError{
                print("\(error)")
            }
        })
        
        // MARK: PEER_EVENT_OPEN
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_OPEN,callback:{ (obj) -> Void in
            if let peerId = obj as? String{
                self._id = peerId
                // UI更新のためメインスレッドで実行
                DispatchQueue.main.async {
                    self.idLabel.text = "your ID: \(peerId)"
                }
            }
        })
        
        // MARK: 3.3．相手からの着信
        
        //コールバックを登録（CONNECTION)
        // MARK: PEER_EVENT_CONNECTION
        _peer?.on(SKWPeerEventEnum.PEER_EVENT_CONNECTION, callback: { (obj) -> Void in
            if let connection = obj as? SKWDataConnection{
                self._data = connection
                self.setDataCallbacks(data: connection)
                self._bEstablished = true
                self.updateUI()
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

//  MARK: 3.4.　相手へのデータ発信

extension DataConnectionViewController{
    
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
    
    //データチャンネルを開く
    func connect(strDestId: String) {
        let options = SKWConnectOption()
        options.label = "chat"
        options.metadata = "{'message': 'hi'}"
        options.serialization = SKWSerializationEnum.SERIALIZATION_BINARY
        options.reliable = true
        
        //接続
        _data = _peer?.connect(withId: strDestId, options: options)
        setDataCallbacks(data: self._data!)
        self.updateUI()
    }
    
    
    //接続を終了する
    func close(){
        if _bEstablished == false{
            return
        }
        _bEstablished = false
        
        if _data != nil {
            _data?.close()
        }
    }
    
    
    //テキストデータを送信する
    func send(data:String){
        let bResult:Bool = (_data?.send(data as NSObject!))!
        
        if bResult == true {
            self.appendLogWithHead(strHeader: "You", value: data)
        }
    }
    
    
    func showPeerDialog(){
        let alert: UIAlertController = UIAlertController(title: "Select Call PeerID", message: nil, preferredStyle:  .alert)
        for peerId in _listPeerIds{
            let action = UIAlertAction(title: peerId, style: .default) { _ in
                self.connect(strDestId: peerId)
            }
            alert.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: Manage Data Connection

extension DataConnectionViewController{
    
    //データチャネルのコールバック処理
    fileprivate func setDataCallbacks(data:SKWDataConnection){
        
        //コールバックを登録(チャンネルOPEN)
        // MARK: DATACONNECTION_EVENT_OPEN
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_OPEN, callback: { (obj) -> Void in
            self.appendLogWithHead(strHeader: "system", value: "DataConnection opened")
            self._bEstablished = true;
            self.updateUI();
        })
        
        // コールバックを登録(DATA受信)
        // MARK: DATACONNECTION_EVENT_DATA
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_DATA, callback: { (obj) -> Void in
            let strValue:String = obj as! String
            self.appendLogWithHead(strHeader: "Partner", value: strValue)
            
        })
        
        // コールバックを登録(チャンネルCLOSE)
        // MARK: DATACONNECTION_EVENT_CLOSE
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_CLOSE, callback: { (obj) -> Void in
            self._data = nil
            self._bEstablished = false
            self.updateUI()
            self.appendLogWithHead(strHeader: "system", value:"DataConnection closed.")
        })
    }
}

// MARK: 2.6.　UIのセットアップ

extension DataConnectionViewController{
    
    
    func updateUI(){
        DispatchQueue.main.async {
            
            //CALLボタンのアップデート
            if self._bEstablished == false{
                self.callButton.setTitle("CALL", for: UIControlState.normal)
            }else{
                self.callButton.setTitle("DISCONNECT", for: UIControlState.normal)
            }
            
            //IDラベルのアップデート
            if self.idLabel == nil{
                self.idLabel.text = "your Id:"
            }else{
                self.idLabel.text = "your Id:"+self._id! as String
            }
            
            self.sendButton.isEnabled = self._bEstablished
        }
    }
    
    @IBAction func pushCallButton(sender: AnyObject) {
        if _data == nil {
            self.getPeerList()
        }else{
            self.close()
        }
    }
    
    @IBAction func pushSendButton(sender: AnyObject) {
        let data:String = self.editMessageTextField.text!;
        self.send(data: data)
        self.editMessageTextField.text = ""
    }
}

// MARK: 2.6.　ハンズオンここまで

extension DataConnectionViewController{
    
    func appendLogWithMessage(strMessage:String){
        var rng = NSMakeRange((logTextView.text?.characters.count)! + 1, 0)
        logTextView.selectedRange = rng
        logTextView.replace(logTextView.selectedTextRange!, withText: strMessage)
        rng = NSMakeRange(logTextView.text.characters.count + 1, 0)
        logTextView.scrollRangeToVisible(rng)
        
    }
    
    func appendLogWithHead(strHeader: String?, value strValue: String) {
        guard let header = strHeader else{
            return
        }
        
        var res = "[\(header)]"
        
        if 32000 < strValue.characters.count {
            let top32Chars  = strValue.substring(to: strValue.index(strValue.startIndex, offsetBy: 32))
            let last32Chars = strValue.substring(to: strValue.index(strValue.endIndex, offsetBy: -32))
            res += "\(top32Chars)...\(last32Chars)"
        } else {
            res += strValue
        }
        res += "\n"
        DispatchQueue.main.async {
            self.appendLogWithMessage(strMessage: res)
        }
    }
}

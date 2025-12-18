//
//  SingleCallVideoLayout.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/19.
//

import UIKit
import RTCCommon
import RTCRoomEngine

private let kCallKitSingleSmallVideoViewWidth = 100.0

class SingleCallVideoLayout: UIView, GestureViewDelegate {
    private let callStatusObserver = Observer()
    private let isVirtualBackgroundOpenedObserver = Observer()
    private let isCameraOpenedObserver = Observer()
    private let videoAvailableObserver = Observer()
    private let remoteVideoAvailableObserver = Observer()
    private let remoteCallStatusObserver = Observer()

    private var isViewReady: Bool = false
    private var selfUserIsLarge = true
    
    private var selfVideoView: VideoView {
        guard let videoView = VideoFactory.shared.createVideoView(user: CallManager.shared.userState.selfUser, isShowFloatWindow: false) else {
            Logger.error("SingleCallVideoLayout->selfVideoView, create video view failed")
            return VideoView(user: CallManager.shared.userState.selfUser, isShowFloatWindow: false)
        }
        return videoView
    }
    
    private var remoteVideoView: VideoView {
        if let remoteUser = CallManager.shared.userState.remoteUserList.value.first {
            if let videoView = VideoFactory.shared.createVideoView(user: remoteUser, isShowFloatWindow: false) {
                return videoView
            }
        }
        Logger.error("SingleCallVideoLayout->remoteVideoView, create video view failed")
        return VideoView(user: User(), isShowFloatWindow: false)
    }
    
    private let userHeadImageView: UIImageView = {
        let userHeadImageView = UIImageView(frame: CGRect.zero)
        userHeadImageView.layer.masksToBounds = true
        userHeadImageView.layer.cornerRadius = 6.0
        if let user = CallManager.shared.userState.remoteUserList.value.first {
            userHeadImageView.sd_setImage(with: URL(string: user.avatar.value), placeholderImage: CallKitBundle.getBundleImage(name: "default_user_icon"))
        }
        return userHeadImageView
    }()
    
    private let userNameLabel: UILabel = {
        let userNameLabel = UILabel(frame: CGRect.zero)
        userNameLabel.textColor = UIColor(hex: "#D5E0F2")
        userNameLabel.font = UIFont.boldSystemFont(ofSize: 18.0)
        userNameLabel.backgroundColor = UIColor.clear
        userNameLabel.textAlignment = .center
        userNameLabel.lineBreakMode = .byTruncatingTail
        userNameLabel.numberOfLines = 1
        if let user = CallManager.shared.userState.remoteUserList.value.first {
            userNameLabel.text = UserManager.getUserDisplayName(user: user)
        }
        return userNameLabel
    }()
        
    // MARK: Init, deinit
    override init(frame: CGRect) {
        super.init(frame: frame)
        updateView()
        registerObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        unregisterobserver()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isViewReady {
            // 如果视图已经初始化，但窗口切换了（比如从横幅切换到主窗口），需要更新视图
            if window != nil {
                // 延迟更新，确保窗口已经完全切换
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateView()
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            }
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 确保在布局更新时视频视图保持可见
        if CallManager.shared.callState.mediaType.value == .video {
            selfVideoView.alpha = 1.0
            remoteVideoView.alpha = 1.0
        }
        updateVideoFrames()
    }
    
    @objc private func orientationChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 确保视频视图在布局更新前保持可见，避免黑屏
            self.selfVideoView.alpha = 1.0
            self.remoteVideoView.alpha = 1.0
            // 立即更新布局，避免延迟导致的黑屏
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
        
    private func constructViewHierarchy() {
        if CallManager.shared.callState.mediaType.value == .video {
            addSubview(selfVideoView)
        }
        addSubview(remoteVideoView)
        addSubview(userHeadImageView)
        addSubview(userNameLabel)
    }
    
    private func activateConstraints() {
        userHeadImageView.translatesAutoresizingMaskIntoConstraints = false 
        userNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            userHeadImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            userHeadImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -100.scale375Width()),
            userHeadImageView.widthAnchor.constraint(equalToConstant: 100.scale375Width()),
            userHeadImageView.heightAnchor.constraint(equalToConstant: 100.scale375Width()),
            
            userNameLabel.topAnchor.constraint(equalTo: userHeadImageView.bottomAnchor, constant: 10.scale375Height()),
            userNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            userNameLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32.scale375Width()),
            userNameLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        if CallManager.shared.callState.mediaType.value == .audio {
            remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                remoteVideoView.topAnchor.constraint(equalTo: topAnchor),
                remoteVideoView.leadingAnchor.constraint(equalTo: leadingAnchor),
                remoteVideoView.trailingAnchor.constraint(equalTo: trailingAnchor),
                remoteVideoView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            remoteVideoView.translatesAutoresizingMaskIntoConstraints = true
            selfVideoView.translatesAutoresizingMaskIntoConstraints = true
            updateVideoFrames()
        }
    }
    
    private func updateVideoFrames() {
        guard CallManager.shared.callState.mediaType.value == .video else { return }
        
        // 确保 bounds 有效，避免无效的 frame 导致黑屏
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let isLandscape = !WindowUtils.isPortrait
        let smallWidth = kCallKitSingleSmallVideoViewWidth
        let smallHeight = smallWidth / 9.0 * 16.0
        
        let smallFrame: CGRect = isLandscape ?
            CGRect(x: bounds.width - smallWidth - 20,
                   y: StatusBar_Height + 20,
                   width: smallWidth,
                   height: smallHeight) :
            CGRect(x: bounds.width - smallWidth - 10,
                   y: StatusBar_Height + 40,
                   width: smallWidth,
                   height: smallHeight)
        
        let largeFrame = bounds
        
        // 确保 frame 有效
        let selfFrame = selfUserIsLarge ? largeFrame : smallFrame
        let remoteFrame = selfUserIsLarge ? smallFrame : largeFrame
        
        // 使用动画更新 frame，避免突然变化导致黑屏
        if selfVideoView.frame != selfFrame || remoteVideoView.frame != remoteFrame {
            UIView.performWithoutAnimation {
                selfVideoView.frame = selfFrame
                remoteVideoView.frame = remoteFrame
                // 确保视频视图可见
                selfVideoView.alpha = 1.0
                remoteVideoView.alpha = 1.0
            }
            bringSubviewToFront(selfUserIsLarge ? remoteVideoView : selfVideoView)
        }
    }
    
    
    private func bindInteraction() {
        if CallManager.shared.callState.mediaType.value == .video {
            selfVideoView.delegate = self
        }
        remoteVideoView.delegate = self
    }
    
    // MARK: Observer
    private func registerObserver() {
        CallManager.shared.userState.selfUser.callStatus.addObserver(callStatusObserver) { [weak self] newValue, _ in
            guard let self = self else { return }
            if newValue == .none { return }
            self.updateView()
            self.switchPreview()
        }
        
        CallManager.shared.viewState.isVirtualBackgroundOpened.addObserver(isVirtualBackgroundOpenedObserver) { [weak self] newValue, _ in
            guard let self = self else { return }
            if newValue && !self.selfUserIsLarge {
                self.switchPreview()
            }
        }
        
        CallManager.shared.mediaState.isCameraOpened.addObserver(isCameraOpenedObserver) { [weak self] _, _ in
            guard let self = self else { return }
            self.updateView()
        }
        
        CallManager.shared.userState.selfUser.videoAvailable.addObserver(videoAvailableObserver) { [weak self] _, _ in
            guard let self = self else { return }
            self.updateView()
        }
        
        // 监听远程用户的视频状态变化，确保窗口切换后能正确显示视频
        if let remoteUser = CallManager.shared.userState.remoteUserList.value.first {
            remoteUser.videoAvailable.addObserver(remoteVideoAvailableObserver) { [weak self] _, _ in
                guard let self = self else { return }
                self.updateView()
            }
            
            remoteUser.callStatus.addObserver(remoteCallStatusObserver) { [weak self] _, _ in
                guard let self = self else { return }
                self.updateView()
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(orientationChanged),
                                             name: UIDevice.orientationDidChangeNotification,
                                             object: nil)
    }
    
    private func unregisterobserver() {
        CallManager.shared.userState.selfUser.callStatus.removeObserver(callStatusObserver)
        CallManager.shared.viewState.isVirtualBackgroundOpened.removeObserver(isVirtualBackgroundOpenedObserver)
        CallManager.shared.mediaState.isCameraOpened.removeObserver(isCameraOpenedObserver)
        CallManager.shared.userState.selfUser.videoAvailable.removeObserver(videoAvailableObserver)
        
        // 移除远程用户的观察者
        if let remoteUser = CallManager.shared.userState.remoteUserList.value.first {
            remoteUser.videoAvailable.removeObserver(remoteVideoAvailableObserver)
            remoteUser.callStatus.removeObserver(remoteCallStatusObserver)
        }
        
        NotificationCenter.default.removeObserver(self,
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }
    
    private func updateView() {
        updateUserInfo()
        
        if CallManager.shared.callState.mediaType.value == .audio {
            remoteVideoView.isHidden = false
            return
        }
        
        if CallManager.shared.userState.selfUser.videoAvailable.value == false &&
           CallManager.shared.mediaState.isCameraOpened.value == true {
            CallManager.shared.openCamera(videoView: selfVideoView.getVideoView()) { }
            fail: { code, message in }
        }

        // 判断是否应该显示视频：接听状态、摄像头打开、有视频流
        let isAccepted = CallManager.shared.userState.selfUser.callStatus.value == .accept
        let isCameraOpened = CallManager.shared.mediaState.isCameraOpened.value == true
        let selfHasVideo = CallManager.shared.userState.selfUser.videoAvailable.value == true
        
        // 检查对方是否有视频流
        var remoteHasVideo = false
        if let remoteUser = CallManager.shared.userState.remoteUserList.value.first {
            remoteHasVideo = remoteUser.videoAvailable.value == true && remoteUser.callStatus.value == .accept
        }
        
        // 判断是否应该显示视频：
        // 1. 已接通状态
        // 2. 自己或对方有视频流（即使自己关闭摄像头，只要对方有视频流也应该显示）
        let shouldShowVideo = isAccepted && (selfHasVideo || remoteHasVideo)
        
        if shouldShowVideo {
            // 有视频流时，容器背景设置为clear，让视频显示
            backgroundColor = UIColor.clear
            
            // 根据视频流情况设置背景：有视频流显示视频（clear），没有视频流显示绿色背景
            if selfHasVideo && isCameraOpened {
                // 自己有视频流且摄像头打开，背景设置为clear，显示视频
                selfVideoView.setBackgroundColor(UIColor.clear)
                selfVideoView.isHidden = false
            } else {
                // 自己没有视频流或摄像头关闭，显示配置的背景颜色
                selfVideoView.setBackgroundColor(CallManager.shared.globalState.waitingBackgroundColor)
                selfVideoView.isHidden = false
            }
            
            if remoteHasVideo {
                // 对方有视频流，背景设置为clear，显示视频
                remoteVideoView.setBackgroundColor(UIColor.clear)
                remoteVideoView.isHidden = false
                if let remoteUser = CallManager.shared.userState.remoteUserList.value.first {
                    CallManager.shared.startRemoteView(user: remoteUser, videoView: remoteVideoView.getVideoView())
                }
            } else {
                // 对方没有视频流，显示配置的背景颜色
                remoteVideoView.setBackgroundColor(CallManager.shared.globalState.waitingBackgroundColor)
                remoteVideoView.isHidden = false
            }
            
            // 隐藏背景头像（确保隐藏）
            selfVideoView.setBackgroundAvatarHidden(true)
            remoteVideoView.setBackgroundAvatarHidden(true)
            
            // 强制刷新视图
            selfVideoView.setNeedsLayout()
            remoteVideoView.setNeedsLayout()
            setNeedsLayout()
        } else {
            // 其他状态都显示配置的背景颜色
            let waitingColor = CallManager.shared.globalState.waitingBackgroundColor
            backgroundColor = waitingColor
            selfVideoView.setBackgroundColor(waitingColor)
            remoteVideoView.setBackgroundColor(waitingColor)
            
            // 隐藏背景头像
            selfVideoView.setBackgroundAvatarHidden(true)
            remoteVideoView.setBackgroundAvatarHidden(true)
            
            if CallManager.shared.userState.selfUser.callStatus.value == .waiting {
                remoteVideoView.isHidden = true
                selfVideoView.isHidden = false
            } else {
                // 非等待状态但也不显示视频时，隐藏视频视图
                remoteVideoView.isHidden = true
                selfVideoView.isHidden = true
            }
        }
        
        // 始终隐藏模糊效果
        selfVideoView.setBlurBackground(hidden: true)
        remoteVideoView.setBlurBackground(hidden: true)
    }
    
    private func switchPreview() {
        guard CallManager.shared.callState.mediaType.value == .video else { return }
        
        selfUserIsLarge = !selfUserIsLarge
        UIView.animate(withDuration: 0.3) {
            self.updateVideoFrames()
        }
    }
    
    private func updateUserInfo() {
        if CallManager.shared.userState.selfUser.callStatus.value == .accept &&
           CallManager.shared.callState.mediaType.value == .video {
            userHeadImageView.isHidden = true
            userNameLabel.isHidden = true
        }
        
        // 在等待状态或关闭摄像头状态时隐藏对方头像和名字
        let isWaiting = CallManager.shared.userState.selfUser.callStatus.value == .waiting
        let isCameraClosed = CallManager.shared.mediaState.isCameraOpened.value == false || 
                            CallManager.shared.userState.selfUser.videoAvailable.value == false
        
        if (isWaiting || isCameraClosed) &&
           CallManager.shared.callState.mediaType.value == .video {
            userHeadImageView.isHidden = true
            userNameLabel.isHidden = true
        }
    }
    
    // MARK: Gesture Action
    @objc func tapGestureAction(tapGesture: UITapGestureRecognizer) {
        if  tapGesture.view?.frame.size.width == CGFloat(kCallKitSingleSmallVideoViewWidth) {
            switchPreview()
            return
        }
        
        if CallManager.shared.userState.selfUser.callStatus.value == .accept {
            CallManager.shared.viewState.isScreenCleaned.value = !CallManager.shared.viewState.isScreenCleaned.value
        }
    }
    
    @objc func panGestureAction(panGesture: UIPanGestureRecognizer) {
        guard let smallView = panGesture.view?.superview,
              smallView.frame.size.width == kCallKitSingleSmallVideoViewWidth else { return }
        
        if panGesture.state == .changed {
            let translation = panGesture.translation(in: self)
            let newCenterX = translation.x + smallView.center.x
            let newCenterY = translation.y + smallView.center.y
            
            let minX = smallView.bounds.width / 2
            let maxX = bounds.width - smallView.bounds.width / 2
            let minY = smallView.bounds.height / 2
            let maxY = bounds.height - smallView.bounds.height / 2
            
            let clampedX = min(max(newCenterX, minX), maxX)
            let clampedY = min(max(newCenterY, minY), maxY)
            
            UIView.animate(withDuration: 0.1) {
                smallView.center = CGPoint(x: clampedX, y: clampedY)
            }
            panGesture.setTranslation(.zero, in: self)
        }
    }
}

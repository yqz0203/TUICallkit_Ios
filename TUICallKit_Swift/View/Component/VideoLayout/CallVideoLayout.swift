//
//  CallVideoLayout.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/19.
//

import RTCCommon

public class CallVideoLayout: UIView {
    private var isViewReady = false
    private let aiSubtitle = AISubtitle(frame: .zero)
    private var singleCallingView: SingleCallVideoLayout?
    private var multiCallingView: MultiCallVideoLayout?
    private let routerObserver = Observer()
    private var previousRouter: ViewState.ViewRouter = .none
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        previousRouter = CallManager.shared.viewState.router.value
        registerObserver()
        
        
        self.layer.borderWidth=2.0;
        self.layer.borderColor = UIColor.yellow.cgColor;
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        CallManager.shared.viewState.router.removeObserver(routerObserver)
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            // 如果视图已经初始化，但窗口切换了（比如从横幅切换到主窗口），需要更新视图
            if window != nil && CallManager.shared.viewState.router.value == .fullView {
                updateVideoViewAfterWindowSwitch()
            }
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }
    
    private func registerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // 监听窗口切换，当从横幅窗口切换到主窗口时，更新视频视图
        CallManager.shared.viewState.router.addObserver(routerObserver) { [weak self] newValue, _ in
            guard let self = self else { return }
            // 当从横幅窗口切换到主窗口时，更新视频视图
            if self.previousRouter == .banner && newValue == .fullView {
                DispatchQueue.main.async {
                    self.updateVideoViewAfterWindowSwitch()
                }
            }
            // 更新保存的 router 值
            self.previousRouter = newValue
        }
    }
    
    private func updateVideoViewAfterWindowSwitch() {
        // 确保视图已经初始化
        guard isViewReady else { return }
        
        // 强制更新子视图
        if CallManager.shared.viewState.callingViewType.value == .one2one {
            // 直接调用 updateView 来更新视频显示状态
            if let singleView = singleCallingView {
                // 使用 performSelector 或者直接访问私有方法，但更好的方式是触发状态更新
                // 通过设置 needsLayout 来触发 layoutSubviews
                singleView.setNeedsLayout()
                singleView.layoutIfNeeded()
            }
        } else if CallManager.shared.viewState.callingViewType.value == .multi {
            multiCallingView?.setNeedsLayout()
            multiCallingView?.layoutIfNeeded()
            multiCallingView?.updateCollectionViewLayout()
        }
        
        // 确保视图可见
        singleCallingView?.alpha = 1.0
        multiCallingView?.alpha = 1.0
        
        // 延迟一点时间后再次更新，确保视频流已经准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if CallManager.shared.viewState.callingViewType.value == .one2one {
                self.singleCallingView?.setNeedsLayout()
                self.singleCallingView?.layoutIfNeeded()
            }
        }
    }

    private func constructViewHierarchy() {
        if CallManager.shared.viewState.callingViewType.value == .one2one {
            singleCallingView = SingleCallVideoLayout(frame: .zero)
            if let singleCallingView = singleCallingView {
                addSubview(singleCallingView)
            }
        } else {
            multiCallingView = MultiCallVideoLayout(frame: .zero)
            if let multiCallingView = multiCallingView {
                addSubview(multiCallingView)
            }
        }

        addSubview(aiSubtitle)
    }
    
    private var activeConstraints: [NSLayoutConstraint] = []
    
    private func activateConstraints() {
        // 先激活新约束，再停用旧约束，避免视图暂时失去布局导致黑屏
        aiSubtitle.translatesAutoresizingMaskIntoConstraints = false
        var newConstraints: [NSLayoutConstraint] = [
            aiSubtitle.centerXAnchor.constraint(equalTo: centerXAnchor),
            aiSubtitle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -220.scale375Height()),
            aiSubtitle.heightAnchor.constraint(equalToConstant: 200.scale375Height()),
            aiSubtitle.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.95)
        ]
        
        if CallManager.shared.viewState.callingViewType.value == .one2one, let singleCallingView = singleCallingView {
            singleCallingView.translatesAutoresizingMaskIntoConstraints = false
            newConstraints += [
                singleCallingView.topAnchor.constraint(equalTo: topAnchor),
                singleCallingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                singleCallingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                singleCallingView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ]
        } else if let multiCallingView = multiCallingView {
            multiCallingView.translatesAutoresizingMaskIntoConstraints = false
            newConstraints += [
                multiCallingView.topAnchor.constraint(equalTo: topAnchor),
                multiCallingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                multiCallingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                multiCallingView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -groupSmallFunctionViewHeight - 10.scale375Height())
            ]
        }
        
        // 先激活新约束
        NSLayoutConstraint.activate(newConstraints)
        // 再停用旧约束
        NSLayoutConstraint.deactivate(activeConstraints)
        // 保存当前激活的约束
        activeConstraints = newConstraints
    }
    
    // MARK: - Orientation Handling
    @objc private func handleOrientationChange() {
        guard UIDevice.current.orientation.isValidInterfaceOrientation else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 确保视图在布局更新前保持可见，避免黑屏
            self.singleCallingView?.alpha = 1.0
            self.multiCallingView?.alpha = 1.0
            
            // 处理所有模式的布局更新
            UIView.animate(withDuration: 0.3, animations: {
                self.activateConstraints()
                self.layoutIfNeeded()
                
                // 对于 one2one 模式，确保子视图也更新布局
                if CallManager.shared.viewState.callingViewType.value == .one2one {
                    self.singleCallingView?.setNeedsLayout()
                    self.singleCallingView?.layoutIfNeeded()
                } else if CallManager.shared.viewState.callingViewType.value == .multi {
                    self.multiCallingView?.setNeedsLayout()
                    self.multiCallingView?.layoutIfNeeded()
                }
            }, completion: { _ in
                // 布局完成后，确保所有视图都可见
                self.singleCallingView?.alpha = 1.0
                self.multiCallingView?.alpha = 1.0
            })
        }
    }
}

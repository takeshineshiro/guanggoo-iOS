//
//  CenterViewController.swift
//  guanggoo-iOS
//
//  Created by tdx on 2017/12/11.
//  Copyright © 2017年 tdx. All rights reserved.
//

import UIKit
import SnapKit
import SDWebImage
import MJRefresh
import MBProgressHUD

class CenterViewController: UIViewController ,UITableViewDelegate,UITableViewDataSource,GuangGuVCDelegate{
    //MARK: - init
    fileprivate let appDelegate = UIApplication.shared.delegate as! AppDelegate;
    fileprivate var homePageData:HomePageDataSource?;
    fileprivate var mURLString:String?;
    var needRefreshInAppear:Bool = false;
    
    fileprivate var _tableView: UITableView!;
    fileprivate var tableView: UITableView {
        get {
            guard _tableView == nil else {
                return _tableView;
            }
            
            _tableView = UITableView.init();
            _tableView.delegate = self;
            _tableView.dataSource = self;
            _tableView.backgroundColor = UIColor.white;
            
            _tableView.mj_header = MJRefreshNormalHeader.init(refreshingTarget: self, refreshingAction: #selector(CenterViewController.reloadItemData));
            _tableView.mj_footer = MJRefreshAutoNormalFooter.init(refreshingTarget: self, refreshingAction: #selector(CenterViewController.nextPage));
            _tableView.mj_footer.isHidden = true;
            
            return _tableView;
        }
    }
    
    fileprivate var createTitleButton:UIButton?;
    //MARK: - UIViewController
    required init(urlString:String?) {
        super.init(nibName: nil, bundle: nil);
        guard let count = urlString?.count,count > 0 else {
            return;
        }
        self.mURLString = urlString;
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if (self.mURLString?.contains("www.guanggoo.com/u/"))! {
            //用户主题，不需要初始化左侧边栏
        }
        else {
            setNavBarItem();
        }
        self.view.backgroundColor = UIColor.white;
        self.view.addSubview(self.tableView);
        self.tableView.snp.makeConstraints { (make) in
            make.left.right.top.equalTo(self.view);
            if #available(iOS 11, *) {
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin);
            } else {
                make.bottom.equalTo(self.view);
            }
        }
        //解决mj下拉刷新出切出去，再切回来上拉头部没有回弹回去的问题
        self.navigationController?.navigationBar.isTranslucent = false;
        //黑名单更新
        NotificationCenter.default.addObserver(self, selector: #selector(blackListFresh(notification:)), name: NSNotification.Name(rawValue: BLACKLISTTOREFRESH), object: nil);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //首页消失时去除右滑打开左边页面手势，出现时恢复手势操作
    override func viewWillAppear(_ animated: Bool) {
        appDelegate.drawController?.openDrawerGestureModeMask = .panningCenterView
    }
    override func viewWillDisappear(_ animated: Bool) {
        appDelegate.drawController?.openDrawerGestureModeMask = []
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        
        if self.homePageData == nil || needRefreshInAppear {
            MBProgressHUD.showAdded(to: self.view, animated: true);
            DispatchQueue.global(qos: .background).async {
                self.homePageData = HomePageDataSource.init(urlString: self.mURLString!);
                DispatchQueue.main.async {
                    self.tableView.mj_footer.isHidden = false;
                    self.tableView.reloadData();
                    if (self.homePageData?.pageCount)! >= (self.homePageData?.maxCount)! {
                        self.endRefreshingWithNoMoreData()
                    }
                    MBProgressHUD.hide(for: self.view, animated: true);
                    if GuangGuAccount.shareInstance.isLogin() && self.homePageData?.homePageString == GUANGGUSITE {
                        self.view.makeToast(GuangGuAccount.shareInstance.notificationText, duration: 1.0, position: .center);
                    }
                }
            }
        }
    }
    
    func setNavBarItem() -> Void {
        let leftButton = UIButton.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40));
        leftButton.setImage(UIImage.init(named: "ic_menu_36pt"), for: .normal);
        leftButton.imageEdgeInsets = UIEdgeInsetsMake(10, 0, 10, 20);
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftButton);
        leftButton.addTarget(self, action: #selector(CenterViewController.leftClick(sender:)), for: .touchUpInside);
        
        let rightView = UIView.init(frame: CGRect(x: 0, y: 0, width: 80, height: 40));
        self.createTitleButton = UIButton.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40));
        self.createTitleButton!.setImage(UIImage.init(named: "ic_create_title"), for: .normal);
        self.createTitleButton!.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -15);
        self.createTitleButton?.addTarget(self, action: #selector(CenterViewController.createTitleClick(sender:)), for: UIControlEvents.touchUpInside);
        rightView.addSubview(self.createTitleButton!);
        self.createTitleButton?.isHidden = true;
        
        let rightButton = UIButton.init(frame: CGRect(x: 40, y: 0, width: 40, height: 40));
        rightButton.setImage(UIImage.init(named: "ic_more_horiz_36pt"), for: .normal);
        rightButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -15);
        rightView.addSubview(rightButton);
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightView);
        rightButton.addTarget(self, action: #selector(CenterViewController.rightClick(sender:)), for: .touchUpInside);
    }
    
    //MARK: - UITableView Delegate DataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let count = self.homePageData?.itemList.count {
            if count > 0 {
                return count;
            }
            else {
                return 1;
            }
        }
        return 0;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let count = self.homePageData?.itemList.count {
            if count > 0 {
                if let item = self.homePageData?.itemList[indexPath.row] {
                    if BlackDataSource.shareInstance.itemList.contains(item.creatorName) {
                        return 0;
                    }
                    else {
                        let titleWidth = item.title.width(withConstraintedHeight: 20, font: UIFont.systemFont(ofSize: 16));
                        let labelWidth = UIScreen.main.bounds.size.width - 30;
                        let lines = (Int)(titleWidth/labelWidth) + 1;
                        return CGFloat(85+20*lines);
                    }
                }
            }
            else {
                return 0;
            }
        }
        return 0;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let count = self.homePageData?.itemList.count {
            if count > 0 {
                let identifier = "HOMEPAGECELL";
                var cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? HomePageTableViewCell;
                if cell == nil {
                    cell = HomePageTableViewCell.init(style: UITableViewCellStyle.default, reuseIdentifier: identifier);
                }
                if let item = self.homePageData?.itemList[indexPath.row] {
                    cell?.creatorNameLabel.text = item.creatorName;
                    cell?.replyDescriptionLabel.text = item.replyDescription + "  " + item.lastReplyName;
                    cell?.setCount(item.replyCount);
                    cell?.nodeNameLabel.text = item.node;
                    cell?.setTitleContent(item.title);
                    cell?.creatorImageView.sd_setImage(with: URL.init(string: item.creatorImg), completed: nil);
                    if BlackDataSource.shareInstance.itemList.contains(item.creatorName) {
                        cell?.isHidden = true;
                    }
                    else {
                        cell?.isHidden = false;
                    }
                }
                return cell!;
            }
            else {
                let identifier = "NOCELL";
                var cell = tableView.dequeueReusableCell(withIdentifier: identifier);
                if cell == nil {
                    cell = UITableViewCell.init(style: UITableViewCellStyle.default, reuseIdentifier: identifier);
                }
                return cell!;
            }
        }
        return UITableViewCell.init();
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.mj_header.state == MJRefreshState.refreshing || tableView.mj_footer.state == MJRefreshState.refreshing {
            self.view.makeToast("请等待刷新完成!", duration: 1.0, position: .center)
            return;
        }
        if GuangGuAccount.shareInstance.isLogin() {
            if let item = self.homePageData?.itemList[indexPath.row] {
                var titleLink = item.titleLink;
                guard titleLink.count > 0 else {
                    return;
                }
                if titleLink[titleLink.startIndex] == "/" {
                    titleLink.removeFirst();
                }
                if let index = titleLink.index(of: "#") {
                    let link = titleLink[titleLink.startIndex..<index]+"?p=1";
                    let vc = ContentPageViewController.init(urlString: GUANGGUSITE+link,model:item);
                    self.navigationController?.pushViewController(vc, animated: true);
                }
                else {
                    let link = titleLink+"?p=1";
                    let vc = ContentPageViewController.init(urlString: GUANGGUSITE+link,model:item);
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
        }
        else {
            let vc = LoginViewController.init(completion: { [weak self] (loginSuccess) in
                if let weakSelf = self, loginSuccess {
                    if let item = weakSelf.homePageData?.itemList[indexPath.row] {
                        var titleLink = item.titleLink;
                        guard titleLink.count > 0 else {
                            return;
                        }
                        if titleLink[titleLink.startIndex] == "/" {
                            titleLink.removeFirst();
                        }
                        if let index = titleLink.index(of: "#") {
                            let link = titleLink[titleLink.startIndex..<index];
                            let vc = ContentPageViewController.init(urlString: GUANGGUSITE+link,model:item);
                            weakSelf.navigationController?.pushViewController(vc, animated: true);
                            weakSelf.homePageData?.reloadData(completion: {weakSelf.tableView.reloadData()});
                        }
                        else {
                            let link = titleLink;
                            let vc = ContentPageViewController.init(urlString: GUANGGUSITE+link,model:item);
                            weakSelf.navigationController?.pushViewController(vc, animated: true);
                            weakSelf.homePageData?.reloadData(completion: {weakSelf.tableView.reloadData()});
                        }
                    }
                }
            })
            vc.vcDelegate = self;
            //self.navigationController?.pushViewController(vc, animated: true);
            self.present(vc, animated: true, completion: nil);
        }
        
    }
    
    /**
     禁用上拉加载更多，并显示一个字符串提醒
     */
    func endRefreshingWithStateString(_ string:String){
        self.tableView.mj_footer.endRefreshingWithNoMoreData()
    }
    
    func endRefreshingWithNoDataAtAll() {
        self.endRefreshingWithStateString("暂无内容")
    }
    
    func endRefreshingWithNoMoreData() {
        self.endRefreshingWithStateString("没有内容了")
    }
    
    //MARK: - Event
    @objc func leftClick(sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.drawController?.toggleLeftDrawerSide(animated: true, completion: nil);
    }
    
    @objc func rightClick(sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.drawController?.toggleRightDrawerSide(animated: true, completion: nil);
    }
    
    @objc func createTitleClick(sender: UIButton) {
        if GuangGuAccount.shareInstance.isLogin() {
            if var link = self.homePageData?.createTitleLink {
                if link[link.startIndex] == "/" {
                    link.removeFirst();
                }
                let vc = CreateTitleViewController.init(title:"",content:"",urlString: GUANGGUSITE+link, completion: { [weak self](bSuccess) in
                    if bSuccess {
                        self?.tableView.mj_header.beginRefreshing();
                    }
                })
                self.navigationController?.pushViewController(vc, animated: true);
            }
        }
        else {
            self.view.makeToast("请先登录");
        }
    }
    
    @objc func reloadItemData() -> Void {
        self.tableView.mj_footer.isHidden = false;
        self.homePageData?.reloadData {
            self.tableView.mj_header.endRefreshing();
            self.tableView.mj_footer.resetNoMoreData();
            self.tableView.reloadData();
            if GuangGuAccount.shareInstance.isLogin() && self.homePageData?.homePageString == GUANGGUSITE {
                self.view.makeToast(GuangGuAccount.shareInstance.notificationText, duration: 1.0, position: .center);
            }
        };
    }
    
    @objc func nextPage() -> Void {
        if self.homePageData?.itemList.count == 0 {
            self.endRefreshingWithNoDataAtAll()
            return;
        }
        if let pageCount = self.homePageData?.pageCount,let maxCount = self.homePageData?.maxCount ,pageCount >= maxCount
        {
            self.endRefreshingWithNoMoreData()
            return;
        }
        self.homePageData?.loadOlder {
            self.tableView.mj_footer.endRefreshing();
            self.tableView.reloadData();
        }
    }
    
    @objc func blackListFresh(notification: NSNotification) {
        self.tableView.mj_header.beginRefreshing();
    }
    
    func OnPushVC(msg: NSDictionary) {
        if let msgtype = msg["MSGTYPE"] as? String {
            if msgtype == "PhotoBrowser" {
                if let vc = msg["PARAM1"] as? UIViewController{
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "LoginViewController" {
                if let vc = msg["PARAM1"] as? UIViewController{
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "PresentViewController" {
                if let vc = msg["PARAM1"] as? UIViewController{
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "UserInfoViewController" {
                if case let urlString as String = msg["PARAM1"] {
                    let vc = UserInfoViewController.init(urlString: GUANGGUSITE + urlString);
                    vc.vcDelegate = self;
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "ContentPageViewController" {
                if case var urlString as String = msg["PARAM1"] {
                    if let index = urlString.index(of: "#") {
                        urlString = String(urlString[urlString.startIndex..<index])
                    }
                    let vc = ContentPageViewController.init(urlString: urlString,model:nil);
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "PushViewController" {
                if let vc = msg["PARAM1"] as? UIViewController{
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "CenterViewController" {
                if let vc = msg["PARAM1"] as? UIViewController{
                    self.navigationController?.pushViewController(vc, animated: true);
                }
            }
            else if msgtype == "reloadData" {
                self.homePageData?.reloadData(completion: {self.tableView.reloadData()});
            }
            else if msgtype == "GotoHomePage" {
                self.navigationController?.popToRootViewController(animated: true);
                self.homePageData?.reloadData(completion: {self.tableView.reloadData()});
            }
            else if msgtype == "changeNode" {
                if let item = msg["PARAM1"] as? GuangGuNode {
                    var nodeString = item.link;
                    self.createTitleButton?.isHidden = true;
                    //除去全部节点
                    if nodeString.count > 0 {
                        if nodeString[nodeString.startIndex] == "/" {
                            nodeString.removeFirst();
                        }
                    }
                    if GuangGuAccount.shareInstance.isLogin() {
                        if nodeString.count > 0 {
                            self.createTitleButton?.isHidden = false;
                        }
                        self.homePageData?.homePageString = GUANGGUSITE + nodeString;
                        self.title = item.name;
                        self.tableView.mj_header.beginRefreshing();
                        //self.homePageData.reloadData(completion: {self.tableView.reloadData()});
                    }
                    else
                    {
                        let vc = LoginViewController.init(completion: { [weak self] (loginSuccess) in
                            if let weakSelf = self, loginSuccess {
                                weakSelf.homePageData?.homePageString = GUANGGUSITE + nodeString;
                                weakSelf.title = item.name;
                                weakSelf.tableView.mj_header.beginRefreshing();
                                //weakSelf.homePageData.reloadData(completion: {weakSelf.tableView.reloadData()});
                            }
                            else {
                                self?.createTitleButton?.isHidden = true;
                            }
                        })
                        vc.vcDelegate = self;
                        self.present(vc, animated: true, completion: nil);
                    }
                }
            }
        }
    }
}

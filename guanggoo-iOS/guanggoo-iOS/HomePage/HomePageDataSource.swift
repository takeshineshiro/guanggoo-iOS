//
//  HomePageDataSource.swift
//  guanggoo-iOS
//
//  Created by tdx on 2017/12/18.
//  Copyright © 2017年 tdx. All rights reserved.
//

import UIKit
import SwiftSoup
import Alamofire

struct GuangGuStruct {
    var title = "";                                 //回复内容
    var titleLink = "";                             //内容链接
    var creatorImg = "";                            //创建者头像
    var creatorName = "";                           //创建者名称
    var creatTime = "";                             //创建时间
    var creatorLink = "";                           //创建者链接
    var lastReplyName = "";                         //最后回复者名称
    var lastReplyLink = "";                         //最后回复者链接
    var replyDescription = "";                      //回复时间
    var node = "";                                  //所属节点
    var replyCount:Int = 0;                         //回复数
    var contentHtml = "";                           //html内容
    var isFavorite = false;                         //是否收藏
    var favoriteURL = "";                           //收藏操作
    var images:NSMutableArray = NSMutableArray();   //html中的image链接
    mutating func clear() -> Void {
        title = "";
        titleLink = "";
        creatorImg = "";
        creatorName = "";
        creatTime = "";
        creatorLink = "";
        lastReplyName = "";
        lastReplyLink = "";
        replyDescription = "";
        node = "";
        replyCount = 0;
        contentHtml = "";
        isFavorite = false;
        favoriteURL = "";
        images.removeAllObjects();
    }
}



class HomePageDataSource: NSObject {
    
    var homePageString = "";
    var itemList = [GuangGuStruct]();
    var pageCount:Int = 0;
    var maxCount:Int = 1;
    var createTitleLink = "";
    
    required init(urlString: String) {
        super.init();
        guard urlString.count > 0 else {
            return;
        }
        self.homePageString = urlString;
        self.pageCount = 1;
        self.loadData(urlString: self.homePageString, loadNew: true);
    }
    
    func loadData(urlString:String,loadNew:Bool) -> Void {
        guard let myURL = URL(string: urlString) else {
            print("Error: \(urlString) doesn't seem to be a valid URL");
            return
        }
        if (loadNew)
        {
            self.itemList.removeAll();
            self.pageCount = 1;
            self.maxCount = 1;
        }
        do {
            let myHTMLString = try String(contentsOf: myURL, encoding: .utf8)
            
            do{
                let doc: Document = try SwiftSoup.parse(myHTMLString);
                let classes = try doc.getElementsByClass("topic-item");
                for object in classes
                {
                    let topicItemElement = try object.select("img");
                    let topicItemImageSrc: String = try topicItemElement.attr("src")
                    
                    let titleElements = try object.getElementsByClass("title");
                    let titleText = try titleElements.text();
                    let titleElement = try titleElements.select("a");
                    let titleHref: String = try titleElement.attr("href")
                    
                    let metaElements = try object.getElementsByClass("node");
                    let nodeText = try metaElements.text();
                    
                    let userNameElements = try object.getElementsByClass("username");
                    let userNameText = try userNameElements.text();
                    let userNameElement = try userNameElements.select("a");
                    let userNameHref: String = try userNameElement.attr("href")
                    
                    let lastTouchedElements = try object.getElementsByClass("last-touched");
                    let lastTouchedText = try lastTouchedElements.text();
                    
                    let lastReplyElements = try object.getElementsByClass("last-reply-username");
                    let lastReplyText = try lastReplyElements.text();
                    let lastReplyElement = try lastReplyElements.select("a");
                    let lastReplyHref: String = try lastReplyElement.attr("href")
                    
                    let countElements = try object.getElementsByClass("count");
                    let countText = try countElements.text();
                    
                    var item = GuangGuStruct();
                    item.title = titleText;
                    item.titleLink = titleHref;
                    item.node = nodeText;
                    item.creatorImg = topicItemImageSrc;
                    item.creatorName = userNameText;
                    item.creatorLink = userNameHref;
                    item.lastReplyName = lastReplyText;
                    item.lastReplyLink = lastReplyHref;
                    item.replyCount = (countText as NSString).integerValue;
                    item.replyDescription = lastTouchedText;
                    itemList.append(item);
                }
                if urlString.contains("www.guanggoo.com/node/") {
                    let userClasses = try doc.getElementsByClass("topics");
                    for object in userClasses {
                        let uiheaderElement = try object.getElementsByClass("ui-header");
                        let createLinkText = try uiheaderElement.select("a").attr("href");
                        self.createTitleLink = createLinkText;
                    }
                }
                if urlString.contains("www.guanggoo.com/u/") {
                    //用户主题，不需要初始化左侧边栏
                }
                else {
                    //解析用户信息时，只能用SwiftSoup,Ji查到usercard会找不到
                    let userClasses = try doc.getElementsByClass("usercard");
                    for object in userClasses {
                        let userNameElement = try object.getElementsByClass("username");
                        let userNameText = try userNameElement.text();
                        
                        let uiHeaderElements = try object.getElementsByClass("ui-header");
                        let userImgElement = try uiHeaderElements.select("a").select("img");
                        let userImgText = try userImgElement.attr("src");
                        
                        let userLinkElement = try uiHeaderElements.select("a");
                        let userLinkText = try userLinkElement.attr("href");
                        
                        var user = GuangGuUser();
                        user.userImage = userImgText;
                        user.userName = userNameText;
                        user.userLink = userLinkText;
                        GuangGuAccount.shareInstance.user = user;
                        if GuangGuAccount.shareInstance.cookie.count == 0 {
                            self.fetchCookie(urlString: GUANGGUSITE);
                        }
                        
                        //BlackDataSource.shareInstance.reloadData();
                        //BlackDataSource.shareInstance.loginWithToken();
                        break;
                    }
                    if userClasses.array().count == 0 {
                        GuangGuAccount.shareInstance.user?.userImage = "";
                        GuangGuAccount.shareInstance.user?.userLink = "";
                        GuangGuAccount.shareInstance.user?.userName = "";
                        GuangGuAccount.shareInstance.notificationText = "";
                        BlackDataSource.shareInstance.itemList.removeAll();
                    }
                }
                //初始化首页时查看是否有未读消息
                if GuangGuAccount.shareInstance.isLogin() {
                    let notificationClasses = try doc.getElementsByClass("notification-indicator");
                    let nofificationText = try notificationClasses.attr("title");
                    if nofificationText.count > 0 {
                        GuangGuAccount.shareInstance.notificationText = nofificationText;
                    }
                }
                //页数
                let pageElements = try doc.getElementsByClass("pagination");
                for object in pageElements {
                    let elements = try object.select("li");
                    if elements.array().count > 1 {
                        let maxPageElement = elements.array()[elements.array().count-2];
                        let maxPageText = try maxPageElement.select("a").text();
                        if let count = Int(maxPageText),count > 0 {
                            self.maxCount = count;
                        }
                    }
                }
            }catch Exception.Error(let type, let message)
            {
                print("Type:\(type) Error:\(message)");
            }catch{
                print("error");
            }
            
        } catch let error {
            print("Error: \(error)");
        }
    }

    func reloadData(completion: @escaping () -> Void) -> Void {
        DispatchQueue.global(qos: .background).async {
            self.loadData(urlString: self.homePageString, loadNew: true);
            DispatchQueue.main.async {
                completion();
            }
        }
    }
    
    func loadOlder(completion: @escaping () -> Void) -> Void {
        DispatchQueue.global(qos: .background).async {
            self.pageCount += 1;
            self.loadData(urlString: self.homePageString + "?p=" + String(self.pageCount), loadNew: false);
            DispatchQueue.main.async {
                completion();
            }
        }
    }
    
    func fetchCookie(urlString:String) -> Void {
        Alamofire.request(urlString).responseString { (response) in
            switch(response.result) {
            case .success( _):
                if let cookies = HTTPCookieStorage.shared.cookies
                {
                    for object in cookies {
                        if object.name == "_xsrf" {
                            GuangGuAccount.shareInstance.cookie = object.value;
                            return;
                        }
                    }
                }
                break;
            case .failure(_):
                break;
            }
        }
    }
}

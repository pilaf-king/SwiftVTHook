//
//  ViewController.swift
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/2/26.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let myTest = MyTestClass.init()
        

        var result = myTest.oriFunc(_name: "before")
        print("return \(result)")
        
        #warning("自娱自乐可以，在生产环境不要这样做")
        WBOCTest.replace(MyTestClass.self, methodIndex0: 0, withClass: MyTestClass.self, methodIndex1: 1);
        
        result = myTest.oriFunc(_name: "after")
        print("return \(result)")
    }
}

class MyTestClass {
    
    func oriFunc(_name:String) -> String {
        print("call oriFunc \(_name)")
        return "oriFunc "
    }
    
    func repFunc(_name:String) -> String {
        print("call repFunc \(_name)")
        return "repFunc "
    }
}

class SubTestClass : MyTestClass {
    
    override func oriFunc(_name:String) -> String {
        print("subclass oriFunc run \(_name)")
        return "oriFunc"
    }
    
    override func repFunc(_name:String) -> String {
        print("subclass repFunc run \(_name)")
        return "repFunc"
    }
}



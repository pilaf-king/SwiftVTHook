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
        let myTest = MyTestClass.init()
        myTest.helloWorld()
        //hook
        print("\n------ replace MyTestClass.helloWorld() with HookTestClass.helloWorld() -------\n")
        WBOCTest.replace(HookTestClass.self);
        //hook 生效
        myTest.helloWorld()
    }
}

class MyTestClass {
    func helloWorld() {
        print("call helloWorld() in MyTestClass")
    }
}

class SubTestClass: MyTestClass  {
    override func helloWorld() {
        print("call helloWorld() in SubTestClass")
    }
}
class HookTestClass: MyTestClass  {
    override func helloWorld() {
        print("\n********** call helloWorld() in HookTestClass **********")
        super.helloWorld()
        print("********** call helloWorld() in HookTestClass end **********\n")
    }
}


//
//  ViewController.swift
//  heartbeat
//
//  Created by chaostong on 2019/5/27.
//  Copyright © 2019 chaostong. All rights reserved.
//

/*
 https://stackoverflow.com/questions/32493375/how-to-read-heart-rate-from-ios-healthkit-app-using-swift
 */

/*
 24 h
 every 2 hour get 4 points(aver low and highest) include 3 lines
 */

import UIKit
import HealthKit
import AAInfographics

struct bmpNode {
    var date: Date
    var high: Double = -1
    var low: Double = -1
    var average: Double = -1
    
    var datas: [HKQuantitySample] = []
    
    init(_ datas: [HKQuantitySample]) {
        self.datas = datas
        self.date = datas.last!.startDate
        datas.forEach {
            if low < 0 || low > $0.heartRate {
                low = $0.heartRate
            }
            if high < 0 || high < $0.heartRate {
                high = $0.heartRate
            }
        }
        average = datas.reduce(0, { x, y in
            x + y.heartRate
        }) / Double(datas.count)
    }
}

extension HKQuantitySample {
    open var heartRate: Double {
        return self.quantity.doubleValue(for: HKUnit(from: "count/min"))
    }
}

extension Date {
    public var chnDay: String {
        let fmt: DateFormatter = DateFormatter()
        fmt.dateFormat = "yyyy年MM月dd日"
        fmt.locale = Locale(identifier: "zh_Hans_CN")
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        return fmt.string(from: self)
    }
    public var chnHour: String {
        let fmt: DateFormatter = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.locale = Locale(identifier: "zh_Hans_CN")
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        return fmt.string(from: self)
    }
}

extension Array {
    func split() -> (left: [Element], right: [Element]) {
        let ct = self.count
        let half = ct / 2
        let leftSplit = self[0 ..< half]
        let rightSplit = self[half ..< ct]
        return (left: Array(leftSplit), right: Array(rightSplit))
    }
}

class ViewController: UIViewController {
    typealias timeBmp = Dictionary<Int, [HKQuantitySample]>
    let health = HKHealthStore()
    let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
    let heartRateUnit:HKUnit = HKUnit(from: "count/min")
    var heartRateQuery:HKSampleQuery?
    var datas: timeBmp = {
        var datas: timeBmp = [:]
        for hour in 0 ..< 24 {
            datas[hour] = []
        }
        return datas
    }()
    var bmpNodes = [bmpNode]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestAuthorization()
    }
    
    func makeP() {
        let chartViewWidth  = self.view.frame.size.width
        let chartViewHeight = self.view.frame.size.height/2
        let aaChartView = AAChartView()
        aaChartView.frame = CGRect(x:0,y:0,width:chartViewWidth,height:chartViewHeight)
        // 设置 aaChartView 的内容高度(content height)
        // aaChartView?.contentHeight = self.view.frame.size.height
        self.view.addSubview(aaChartView)
        
        let chartModel = AAChartModel()
            .chartType(.areaspline)//图表类型
            .title("今日心跳曲线")//图表主标题
            .subtitle(Date().chnDay)//图表副标题
            .inverted(false)//是否翻转图形
            .yAxisTitle("次/分钟")// Y 轴标题
            .legendEnabled(true)//是否启用图表的图例(图表底部的可点击的小圆点)
            .tooltipValueSuffix("次/分钟")//浮动提示框单位后缀
            .categories(self.bmpNodes.compactMap({ $0.date.chnHour }))
            .colorsTheme(["#E8F2FC","#4686F6","#06caf4","#7dffc0"])//主题颜色数组
            .series([
                AASeriesElement()
                    .type(.areasplinerange)
                    .name("最高")
                    .data(self.bmpNodes.compactMap({ [$0.low, $0.high] }).filter({ $0.first! > .zero }))
                    .toDic()!,
                AASeriesElement()
                    .type(.spline)
                    .name("平均")
                    .data(self.bmpNodes.compactMap({ Int($0.average) }).filter({ $0 > .zero }))
                    .toDic()!,])
        //        绘制图形(创建 AAChartView 实例对象后,首次绘制图形调用此方法)
        //        图表视图对象调用图表模型对象,绘制最终图形
        aaChartView.aa_drawChartWithChartModel(chartModel)
    }
    
    /*Method to get todays heart rate - this only reads data from health kit. */
    func getTodaysHeartRates() {
        //predicate
        let calendar = NSCalendar.current
        let now = Date()
        let components = calendar.dateComponents([.year,.month,.day], from: now)
        guard let startDate:Date = calendar.date(from: components) else { return }
        let endDate: Date? = calendar.date(byAdding: .day, value: 1, to: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.init(rawValue: 0))
        
        //descriptor
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        ]
        heartRateQuery = HKSampleQuery.init(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors, resultsHandler: { (query, results, error) in
            if let error = error {
                print("error \(error.localizedDescription)")
            } else {
                guard let results = results else { return }
                self.printHeartRateInfo(results)
            }
        })
        health.execute(heartRateQuery!)
        
    }//eom
    
    /*used only for testing, prints heart rate info */
    private func printHeartRateInfo(_ results:[HKSample]) {
        for currData in results {
            guard let currData:HKQuantitySample = currData as? HKQuantitySample else { return }
            
            let date = currData.startDate
            let hour = Calendar.current.component(.hour, from: date)
            self.datas[hour]?.append(currData)
            
            print("Heart Rate: \(currData.quantity.doubleValue(for: heartRateUnit))")
            print("quantityType: \(currData.quantityType)")
            print("Start Date: \(currData.startDate)")
            print("End Date: \(currData.endDate)")
            print("Metadata: \(String(describing: currData.metadata))")
            print("UUID: \(currData.uuid)")
            print("Source: \(currData.sourceRevision)")
            print("Device: \(String(describing: currData.device))")
            print("---------------------------------\n")
        }
        let times = self.datas.sorted(by: { $0.key < $1.key })
        
        for nodes in times {
            let split = nodes.value.sorted(by: { $0.startDate < $1.startDate }).split()
            if split.left.count > 0 {
                bmpNodes.append(bmpNode.init(split.left))
            }
            if split.right.count > 0 {
                bmpNodes.append(bmpNode.init(split.right))
            }
        }
        DispatchQueue.main.async {
            if self.bmpNodes.count < 48 {
                for _ in self.bmpNodes.count ..< 48 {
                    var node = self.bmpNodes.first!
                    node.high = -1
                    node.low = -1
                    node.average = -1
                    self.bmpNodes.append(node)
                }
            }
            self.makeP()
        }
    }

    func requestAuthorization() {
        //reading
        let readingTypes:Set = Set( [heartRateType] )
        //writing
        let writingTypes:Set = Set( [heartRateType] )
        //auth request
        health.requestAuthorization(toShare: writingTypes, read: readingTypes) { (success, error) -> Void in
            if let error = error {
                print("error \(error.localizedDescription)")
            } else if success {
                print("ok to read rate data")
                self.getTodaysHeartRates()
            }
        }
    }

}


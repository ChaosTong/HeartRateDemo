//
//  EnvironmentalAudioViewController.swift
//  heartbeat
//
//  Created by chaostong on 2020/4/14.
//  Copyright © 2020 chaostong. All rights reserved.
//

import UIKit
import HealthKit
import AAInfographics

struct audioNode {
    var date: Date
    var high: Double = -1
    var low: Double = -1
    var average: Double = -1

    var data: HKDiscreteQuantitySample!

    init(_ data: HKDiscreteQuantitySample) {
        self.data = data
        self.date = data.startDate

        low = data.minimumQuantity.audioDes
        high = data.maximumQuantity.audioDes
        average = data.averageQuantity.audioDes
    }
}

extension HKQuantity {
    open var audioDes: Double {
        return self.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
    }
}

class EnvironmentalAudioViewController: UIViewController {
    let health = HKHealthStore()
    let audioExposureType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.environmentalAudioExposure)!
    var heartRateQuery:HKSampleQuery?
    var audioNodes = [audioNode]()

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
            .title("今日环境音曲线")//图表主标题
            .subtitle(Date().chnDay)//图表副标题
            .inverted(false)//是否翻转图形
            .yAxisTitle("分贝")// Y 轴标题
            .legendEnabled(true)//是否启用图表的图例(图表底部的可点击的小圆点)
            .tooltipValueSuffix("分贝")//浮动提示框单位后缀
            .categories(self.audioNodes.compactMap({ $0.date.chnHour }))
            .colorsTheme(["#E8F2FC","#4686F6","#06caf4","#7dffc0"])//主题颜色数组
            .series([
                AASeriesElement()
                    .type(.areasplinerange)
                    .name("最高")
                    .data(self.audioNodes.compactMap({ [$0.low, $0.high] }).filter({ $0.first! > .zero }))
                    .toDic()!,
                AASeriesElement()
                    .type(.spline)
                    .name("平均")
                    .data(self.audioNodes.compactMap({ Int($0.average) }).filter({ $0 > .zero }))
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
        heartRateQuery = HKSampleQuery.init(sampleType: audioExposureType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors, resultsHandler: { (query, results, error) in
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
        var audios = [HKDiscreteQuantitySample]()
        for currData in results {
            guard let currData = currData as? HKDiscreteQuantitySample else { return }
            audios.append(currData)
        }
        audios = audios.sorted(by: { $0.startDate < $1.startDate })
        for node in audios {
            audioNodes.append(audioNode.init(node))
        }
        DispatchQueue.main.async {
            self.makeP()
        }
    }

    func requestAuthorization() {
        //reading
        let readingTypes:Set = Set( [audioExposureType] )
        //writing
        let writingTypes:Set = Set( [audioExposureType] )
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

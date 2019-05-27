# HeartRateDemo
use HealthKit desc a line about heartrate  

![demo](https://github.com/ChaosTong/HeartRateDemo/blob/master/demo.gif?raw=true)

## step to make healthkit work
1. in "Capabilities" switch the HealthKit on
2. in Info.plist add "Privacy - Health Share Usage Description" value should be more than 12 words?
 and "Privacy - Health Update Usage Description" if you need to change data of health
3. request for authorization

``` swift
let health = HKHealthStore()
let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
func requestAuthorization() {
      //reading
      let readingTypes:Set = Set( [heartRateType] )
      //writing if you need
      let writingTypes:Set = Set( [heartRateType] )
      //auth request
      health.requestAuthorization(toShare: writingTypes, read: readingTypes) { (success, error) -> Void in
          if let error = error {
              print("error \(error.localizedDescription)")
          } else if success {
              print("ok to read rate data")
              // ok to access data
          }
      }
  }
```
4. query the data you need, too many code, just see the file.
---
通过HealthKit获取心跳数据, 绘制3条曲线(最高、最低、平均)

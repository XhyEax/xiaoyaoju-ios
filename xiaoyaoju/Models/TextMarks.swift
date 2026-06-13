// Models/TextMarks.swift — 注释标号字符处理
import Foundation

// 注释标号：圆圈数字 ①②③…㊿、数字右上角标 ¹²³⁰⁴⁻⁹
// 注释关闭或列表摘要时，从正文中隐藏这些标号
func stripMarks(_ s: String) -> String {
    var out = s
    out.removeAll { ch in
        guard ch.unicodeScalars.count == 1, let v = ch.unicodeScalars.first?.value else { return false }
        return (0x2460...0x2473).contains(v)        // ①-⑳
            || (0x3251...0x325F).contains(v)         // ㉑-㉟
            || (0x32B1...0x32BF).contains(v)         // ㊱-㊿
            || v == 0x00B9 || v == 0x00B2 || v == 0x00B3   // ¹ ² ³
            || v == 0x2070 || (0x2074...0x2079).contains(v) // ⁰ ⁴-⁹
    }
    return out
}

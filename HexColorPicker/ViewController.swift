//
//  ViewController.swift
//  HexColorPicker
//
//  Created by sasha on 7/1/25.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var hueSlider: UISlider!
    @IBOutlet weak var selectedColorView: UIView!      // The 2D gradient picker square
    @IBOutlet weak var colorPreviewView: UIView!       // The small view showing final color
    @IBOutlet weak var hexLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!

    private var indicatorView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(hueSlider != nil, "hueSlider not connected!")
        assert(selectedColorView != nil, "selectedColorView not connected!")
        assert(colorPreviewView != nil, "colorPreviewView not connected!")
        assert(hexLabel != nil, "hexLabel not connected!")
        assert(resetButton != nil, "resetButton not connected!")

        setupHueSlider()
        setupSelectedColorView()
        setupColorPreviewView()
        setupGestures()
        setupIndicator()
        resetColor()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSelectedColorGradient(hue: CGFloat(hueSlider.value))
    }

    private func setupHueSlider() {
        hueSlider.minimumValue = 0.0
        hueSlider.maximumValue = 1.0
        hueSlider.value = 0.0
    }

    private func setupSelectedColorView() {
        selectedColorView.layer.borderColor = UIColor.black.cgColor
        selectedColorView.layer.borderWidth = 1
        selectedColorView.layer.cornerRadius = 8
    }

    private func setupColorPreviewView() {
        colorPreviewView.layer.borderColor = UIColor.black.cgColor
        colorPreviewView.layer.borderWidth = 1
        colorPreviewView.layer.cornerRadius = 8
        colorPreviewView.backgroundColor = .white
    }

    private func setupIndicator() {
        indicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        indicatorView.layer.cornerRadius = 10
        indicatorView.layer.borderColor = UIColor.black.cgColor
        indicatorView.layer.borderWidth = 1
        indicatorView.backgroundColor = .clear
        indicatorView.isHidden = true
        selectedColorView.addSubview(indicatorView)
    }

    private func setupGestures() {
        let pickerGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePickerPan(_:)))
        selectedColorView.addGestureRecognizer(pickerGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(copyHexToClipboard))
        hexLabel.isUserInteractionEnabled = true
        hexLabel.addGestureRecognizer(tapGesture)
    }

    @IBAction func hueSliderChanged(_ sender: UISlider) {
        updateSelectedColorGradient(hue: CGFloat(sender.value))
    }

    private func updateSelectedColorGradient(hue: CGFloat) {
        guard selectedColorView.bounds.width > 0 && selectedColorView.bounds.height > 0 else { return }

        let hueColor = UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)

        // Remove only gradient layers to avoid deleting indicator
        selectedColorView.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }

        // Horizontal: white → hue (saturation)
        let satGradient = CAGradientLayer()
        satGradient.frame = selectedColorView.bounds
        satGradient.colors = [UIColor.white.cgColor, hueColor.cgColor]
        satGradient.startPoint = CGPoint(x: 0, y: 0.5)
        satGradient.endPoint = CGPoint(x: 1, y: 0.5)

        // Vertical: transparent → black (brightness)
        let brightnessGradient = CAGradientLayer()
        brightnessGradient.frame = selectedColorView.bounds
        brightnessGradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        brightnessGradient.startPoint = CGPoint(x: 0.5, y: 0)
        brightnessGradient.endPoint = CGPoint(x: 0.5, y: 1)

        selectedColorView.layer.insertSublayer(satGradient, below: indicatorView.layer)
        selectedColorView.layer.insertSublayer(brightnessGradient, below: indicatorView.layer)
    }

    @objc private func handlePickerPan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: selectedColorView)
        let clampedX = max(0, min(point.x, selectedColorView.bounds.width - 1))
        let clampedY = max(0, min(point.y, selectedColorView.bounds.height - 1))
        let clampedPoint = CGPoint(x: clampedX, y: clampedY)

        indicatorView.center = clampedPoint
        indicatorView.isHidden = false

        let pickedColor = getColor(in: selectedColorView, at: clampedPoint)
        hexLabel.text = pickedColor.toHexString()
        colorPreviewView.backgroundColor = pickedColor
    }

    private func getColor(in view: UIView, at point: CGPoint) -> UIColor {
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return .white }

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let bitmap = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let pixelData = bitmap?.cgImage?.dataProvider?.data else { return .white }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)!

        let bytesPerPixel = 4
        let bytesPerRow = bitmap!.cgImage!.bytesPerRow
        let x = Int(point.x)
        let y = Int(point.y)
        let pixelIndex = (bytesPerRow * y) + x * bytesPerPixel

        let r = CGFloat(data[pixelIndex]) / 255.0
        let g = CGFloat(data[pixelIndex + 1]) / 255.0
        let b = CGFloat(data[pixelIndex + 2]) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    @objc private func copyHexToClipboard() {
        UIPasteboard.general.string = hexLabel.text
        let alert = UIAlertController(title: "Copied", message: "\(hexLabel.text ?? "") copied to clipboard.", preferredStyle: .alert)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            alert.dismiss(animated: true)
        }
    }

    @IBAction func resetColor() {
        hueSlider.value = 0.0
        updateSelectedColorGradient(hue: 0.0)
        hexLabel.text = "#FFFFFF"
        colorPreviewView.backgroundColor = .white
        indicatorView.isHidden = true
    }
}

// UIColor extension for hex conversion
extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let rInt = Int(round(r * 255))
            let gInt = Int(round(g * 255))
            let bInt = Int(round(b * 255))
            return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        } else {
            return "#FFFFFF"
        }
    }
}

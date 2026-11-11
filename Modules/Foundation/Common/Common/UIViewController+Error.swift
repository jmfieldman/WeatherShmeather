//
//  UIViewController+Error.swift
//  Copyright © 2026 WeatherShmeather.
//

import CommonResources
import UIKit

public extension UIViewController {
    /// Shows a failed action's copy in a one-button alert.
    func present(error: some ErrorDialogProviding) {
        let alert = UIAlertController(title: error.errorTitle, message: error.errorBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: .Common.ok, style: .default))
        present(alert, animated: true)
    }
}

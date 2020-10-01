//
//  ResourceViewController.swift
//  Kitsunebi_Example
//
//  Created by Tomoya Hirano on 2018/09/06.
//  Copyright © 2018年 CocoaPods. All rights reserved.
//

import UIKit

protocol ResourceViewControllerDelegate: class {
  func resource(_ viewController: ResourceViewController, didSelected resource: Resource)
}

final class ResourceViewController: UIViewController {
  private var selectedResource: Resource? = nil
  private let resourceStore: ResourceStore = .init()
  private lazy var noticeLabel: UILabel = .init(frame: view.bounds)
  private lazy var tableView: UITableView = .init(frame: view.bounds)
  weak var delegate: ResourceViewControllerDelegate? = nil
  private let emptyResourceMessage: String = """
  Transfer arbitrary directories using itunes.
  There are base.mp4 and alpha.mp4.
  ex: Burning/base.mp4 and Burning/alpha.mp4
  """
  
  static func make(selected resource: Resource?) -> ResourceViewController {
    let vc = ResourceViewController()
    vc.selectedResource = resource
    return vc
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    
    noticeLabel.font = .systemFont(ofSize: 12)
    noticeLabel.numberOfLines = 0
    if #available(iOS 13.0, *) {
      noticeLabel.backgroundColor = .systemBackground
    } else {
      noticeLabel.backgroundColor = .white
    }
    noticeLabel.textAlignment = .center
    view.addSubview(noticeLabel)
    
    tableView.delegate = self
    tableView.dataSource = self
    tableView.backgroundColor = .clear
    tableView.tableFooterView = UIView()
    view.addSubview(tableView)
    
    let left = UIBarButtonItem(barButtonSystemItem: .cancel,
                               target: self,
                               action: #selector(tappedCloseButton))
    navigationItem.leftBarButtonItem = left
    
    let right = UIBarButtonItem(barButtonSystemItem: .refresh,
                                target: self,
                                action: #selector(tappedReloadButton))
    navigationItem.rightBarButtonItem = right
    
    reloadData()
  }
  
  @objc private func tappedCloseButton(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }
  
  @objc private func tappedReloadButton(_ sender: UIBarButtonItem) {
    reloadData()
  }
  
  private func reloadData() {
    try! resourceStore.fetch()
    noticeLabel.text = resourceStore.resources.isEmpty ? emptyResourceMessage : ""
    tableView.reloadData()
  }
}

extension ResourceViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView,
                          numberOfRowsInSection section: Int) -> Int {
    return resourceStore.resources.count
  }
  
  func tableView(_ tableView: UITableView,
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
    let resource = resourceStore.resources[indexPath.row]
    cell.textLabel?.text = resource.name
    let mSize = resource.baseVideoSize
    let baseText = mSize != nil ? "Base w\(mSize!.width) x h\(mSize!.height)" : "base.mp4 not found"
    cell.detailTextLabel?.text = "\(baseText)"
    if let selected = selectedResource, selected.name == resource.name {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let resource = resourceStore.resources[indexPath.row]
    delegate?.resource(self, didSelected: resource)
  }
}

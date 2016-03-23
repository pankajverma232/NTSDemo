
//
//  ViewController.swift
//  NTSDemo
//
//  Created by Pankaj Verma on 22/12/15.
//  Copyright © 2015 Pankaj Verma. All rights reserved.
//

import UIKit
import CoreData
class detailViewVontroller: UIViewController {
    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detail: UITextView!
    override func viewDidLoad() {
        let tapGesture = UITapGestureRecognizer(target: self, action: "tapAction")
        self.view.addGestureRecognizer(tapGesture)
        }
    
    func tapAction(){
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}


class myCell: UITableViewCell {
    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detail: UILabel!
  
}


class Media:NSManagedObject{
    @NSManaged var title: String?
    @NSManaged var detail: String?
    @NSManaged var imageUrl: String?
    @NSManaged var serialNo: NSNumber?
}



//MARK: facade design
class DataDownloadManager:NSObject {
        //managed object context represents a single object space, or scratch pad which manage a collection of managed objects(table rows)
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        var fetchResults : [Media] = []
    
    func downloadDataForURL(url:String, callBack:  ([Media]?) -> Void){
        self.fetchFromCoreData() //old data
        
        let url = NSURL(string: url)
        let urlRequest = NSURLRequest(URL: url!)
        let session = NSURLSession.sharedSession()
        let task =  session.dataTaskWithRequest(urlRequest, completionHandler: {(data, response, error)  in
            if (error == nil) {
                do {
                    let responseDict  = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as! NSDictionary
                    let results = responseDict["results"]! as! [NSDictionary]
                
                    
                    self.mapResponseData(results)           //create managedObjects(rows) from results and fill the scratch pad (table map)
                    self.saveToCoreData()                   //save to core data
                    
                    self.fetchFromCoreData()  //fetch data from database
                    
                    callBack(self.fetchResults)             //send data to caller
                  
                } catch _ {print("error in parsing JSON")}
            }
            else{ //error: could not download from network (offline support)
                self.fetchFromCoreData()  //fetch data from database
                callBack(self.fetchResults) //send data to caller
            }

        })
        task.resume()
    }
    
   
   //MARK: coreData private methods 
    private  func mapResponseData(results:[NSDictionary]){
        let entityDes = NSEntityDescription.entityForName("PERSON", inManagedObjectContext: self.managedObjectContext)
        var index:NSNumber = 0
        for result in results{
            // Here managedObject represents a single row
            let managedObject = NSManagedObject.init(entity: entityDes!, insertIntoManagedObjectContext: self.managedObjectContext)
            managedObject.setValue(result["description"], forKey: "detail")
            managedObject.setValue(result["artistName"], forKey: "title")
            managedObject.setValue(result["screenshotUrls"]![0], forKey: "imageUrl")
            managedObject.setValue(index, forKey: "serialNo")
            index = index.integerValue+1
        }
    }
    
    private   func saveToCoreData(){
         self.managedObjectContext.performBlockAndWait({ () -> Void in  //  wait until process completes
            do{
                try self.managedObjectContext.save()
            }catch{
                print("error in saving coredata.")
            }
         })
        // now delete the useless old data
        self.deleteOldCoreData()
    }
    
    private    func fetchFromCoreData(){
        self.managedObjectContext.performBlockAndWait({ () -> Void in  //  wait until process completes
            do{
                self.fetchResults =  try self.managedObjectContext.executeFetchRequest(NSFetchRequest(entityName: "PERSON")) as! [Media]
            }catch{
                
            }
       })
    }
    
    private   func deleteOldCoreData(){
         self.managedObjectContext.performBlockAndWait({ () -> Void in  //  wait until process completes
        for object in self.fetchResults {
            self.managedObjectContext.deleteObject(object)
        }
             })
    }
    
    
}

class ViewController: UIViewController ,UITableViewDataSource,UITableViewDelegate,UISearchResultsUpdating{
 
    let searchController = UISearchController(searchResultsController: nil) //iOS 8 and later
     var refreshControl = UIRefreshControl() //pull to refresh 
    let downloadManager = DataDownloadManager()
    let url = "https://itunes.apple.com/search?term=apple&media=software"
    var fetchResults : [Media] = [] // Media is the data model class of  core data
    var filteredResult = [Media]() // when searchBar is active
    
    @IBOutlet weak var searchView: UIView!
    @IBOutlet var tableView: UITableView!{
        didSet{
            // searchResultsUpdater is delegate here for protocol : UISearchResultsUpdating
            searchController.searchResultsUpdater = self
            // do not dim the parent view while search is active
            searchController.dimsBackgroundDuringPresentation = false
            // To ensure that the search controller is presented within the bounds of the original view controller.
            definesPresentationContext = true
            
            // refresh control
            refreshControl.backgroundColor = UIColor.grayColor()
            refreshControl.tintColor = UIColor.whiteColor()
            refreshControl.addTarget(self, action: Selector("reloadTableData"), forControlEvents: UIControlEvents.ValueChanged)
            
            searchView.addSubview(searchController.searchBar)
            self.tableView.addSubview(refreshControl)
            
            downloadManager.downloadDataForURL(url) { (person) -> Void in
               self.fetchResults = person!
                self.fetchResults.sortInPlace(self.ascending) //sort
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.tableView.reloadData()
                })
            }
        }
    }
 
    
      override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    func reloadTableData(){
        downloadManager.downloadDataForURL(url) { (person) -> Void in
            self.fetchResults = person!
            self.fetchResults.sortInPlace(self.ascending) //sort
           
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
        }
    }
    
    func ascending(value1: Media, value2: Media) -> Bool {
       return value1.serialNo?.integerValue < value2.serialNo?.integerValue;
    }


    //MARK: tableView datasource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.active && searchController.searchBar.text != "" {
            return filteredResult.count
        }
        print(fetchResults.count)
        return  fetchResults.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("CELL")! as! myCell
        let result:Media
        cell.tag = indexPath.row
        if searchController.active && searchController.searchBar.text != "" {
            result = filteredResult[indexPath.row]
        } else {
            
            result = fetchResults[indexPath.row]
        }
        cell.detail.text = result.detail
        cell.titleLabel.text = "\(result.serialNo!). " + result.title!
        
         var image = UIImage(named: "")
            if let str = result.imageUrl{
                let url = NSURL(string: str)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                if let data = NSData(contentsOfURL: url!){
                     image = UIImage(data: data)
                   
                }
                else{
                    print("temperatorly not found\n")
                }
                dispatch_async(dispatch_get_main_queue()){
                    if cell.tag == indexPath.row{
                        cell.logo.image  = image
                    }
                }
            }
        }
        return cell
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        switch editingStyle {
        case .Delete:
            // remove the deleted item from the model
            let appDel:AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            let context:NSManagedObjectContext = appDel.managedObjectContext
            
            if searchController.active && searchController.searchBar.text != "" {
                context.deleteObject(filteredResult[indexPath.row] as NSManagedObject)
                filteredResult.removeAtIndex(indexPath.row)
            }
            else {
                context.deleteObject(fetchResults[indexPath.row] as NSManagedObject)
                fetchResults.removeAtIndex(indexPath.row)
            }
            
            do{
                try context.save()
            }catch{}
            
            //tableView.reloadData()
            // remove the deleted item from the `UITableView`
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        default:
            return
            
        }
        
    }

    
     //MARK: tableView delegate
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let dvc = storyboard.instantiateViewControllerWithIdentifier("detailViewVontroller") as! detailViewVontroller
        let result:Media
        if searchController.active && searchController.searchBar.text != "" {
            print("selected from Filtered Result\n")
            result = filteredResult[indexPath.row]
        }
        else {
            print("selected from Main\n")
            result = fetchResults[indexPath.row]
        }
        let url = NSURL(string: (result.imageUrl!))
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var image = UIImage(named: "")
            if let data = NSData(contentsOfURL: url!){
                image = UIImage(data: data)
            }
            else{
                print("temperatorly not found\n")
            }
            dispatch_async(dispatch_get_main_queue()){
                dvc.logo?.image  = image
                dvc.titleLabel?.text = result.title
                dvc.detail?.text = result.detail
            }
        }
        if searchController.active && searchController.searchBar.text != "" {
            self.dismissViewControllerAnimated(true, completion: nil)
            self.presentViewController(dvc, animated: true, completion: {})
        }
        else {
            self.dismissViewControllerAnimated(true, completion: nil)
            self.presentViewController(dvc, animated: true, completion: nil)
        }
    }
    
   
    
    //MARK: searchResultUpdating delegate
    func updateSearchResultsForSearchController(searchController: UISearchController){
        filteredResult = fetchResults.filter { result in
            if let detail = result.detail{
                return detail.lowercaseString.containsString(searchController.searchBar.text!.lowercaseString)
            }
            return false
        }
        self.tableView.reloadData()
    }
}
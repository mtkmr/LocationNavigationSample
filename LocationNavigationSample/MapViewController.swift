//
//  MapViewController.swift
//  LocationNavigationSample
//
//  Created by Masato Takamura on 2021/09/18.
//

import UIKit
import MapKit
import CoreLocation

final class MapViewController: UIViewController {

    private var locationManager: CLLocationManager!

    private var myLocation: CLLocation?

    private lazy var mapView: MKMapView = {
        let map = MKMapView()
        map.delegate = self
        map.translatesAutoresizingMaskIntoConstraints = false
        map.showsUserLocation = true
        return map
    }()

    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        let press = UILongPressGestureRecognizer()
        press.addTarget(self, action: #selector(didlongPressed(_:)))
        return press
    }()

    //MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.addSubview(mapView)
        mapView.addGestureRecognizer(longPressRecognizer)

        setupLocationManager()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mapView.frame = view.bounds
    }
    
}

private extension MapViewController {
    @objc
    func didlongPressed(_ sender: UILongPressGestureRecognizer) {
        let locationPressed: CGPoint = sender.location(in: mapView)
        if sender.state == .began {
            return
        }
        let coordinatePressed: CLLocationCoordinate2D = mapView.convert(locationPressed, toCoordinateFrom: mapView)
        addPin(on: mapView, coordinate: coordinatePressed)
    }

    func setupLocationManager() {
        self.locationManager = CLLocationManager()
        locationManager.delegate = self
    }

    func addPin(on map: MKMapView, coordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "緯度: \(coordinate.latitude), 経度: \(coordinate.longitude)"
        DispatchQueue.main.async {
            map.addAnnotation(annotation)
        }
    }

    func showRoute(destination: CLLocation) {
        DispatchQueue.main.async {
            //表示しているルートを除く
            let oldRoutes = self.mapView.overlays
            self.mapView.removeOverlays(oldRoutes)

            //現在地からピンまでのルートを表示
            guard let currentLocation = self.myLocation else { return }
            let sourcePlacemark = MKPlacemark(coordinate: currentLocation.coordinate)
            let destinationPlacemark = MKPlacemark(coordinate: destination.coordinate)

            let directionRequest = MKDirections.Request()
            directionRequest.source = MKMapItem(placemark: sourcePlacemark)
            directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
            directionRequest.transportType = .walking

            let directions = MKDirections(request: directionRequest)
            directions.calculate { response, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                guard let response = response else { return }
                let route: MKRoute = response.routes[0]
                self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            }
        }
    }
}

//MARK: - CLLocationManagerDelegate
extension MapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        self.myLocation = location
        manager.stopUpdatingLocation()
        DispatchQueue.main.async {
            self.mapView.setRegion(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)),
                animated: true)
        }
    }

    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard
            CLLocationManager.locationServicesEnabled()
        else {
            print("「設定」→「プライバシー」→「位置情報サービス」より位置情報の取得を許可してください")
            return
        }

        switch manager.authorizationStatus {
        case .denied:
            print("「設定」アプリから位置情報の取得を許可してください")
        case .restricted:
            print("何らかの制限がかかっています")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        @unknown default:
            fatalError("予期せぬ位置情報認証エラーが発生しました")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}

//MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else {
            return nil
        }
        let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        annotationView.canShowCallout = true

        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let coordinatePressed = view.annotation?.coordinate else { return }
        let locationPressed = CLLocation(
            latitude: coordinatePressed.latitude,
            longitude: coordinatePressed.longitude)
        showRoute(destination: locationPressed)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let route: MKPolyline = overlay as! MKPolyline
        let routeRenderer = MKPolylineRenderer(polyline: route)
        routeRenderer.strokeColor = .systemOrange
        routeRenderer.lineWidth = 3.0
        return routeRenderer
    }
}

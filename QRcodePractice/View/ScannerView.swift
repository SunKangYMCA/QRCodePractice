//
//  ScannerView.swift
//  QRcodePractice
//
//  Created by 강성찬 on 2024-03-24.
//

import SwiftUI
import AVKit

struct ScannerView: View {
    /// QR Code Scanner Properties
    @State private var isScanning: Bool = false
    @State private var session: AVCaptureSession = .init()
    @State private var cameraPermission: Permission = .idle
    /// QR Scanner AV Output
    @State private var qrOutput: AVCaptureMetadataOutput = .init()
    /// Error Properties
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @Environment(\.openURL) private var openURL
    /// Camera QR Output Delegate
    @StateObject private var qrDelegate = QRScannerDelegate()
    /// Scanned Code
    @State private var scannedCode: String = ""
    var body: some View {
        VStack(spacing: 8) {
            Button {
                //
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Place the QR code inside the area")
                .font(.title3)
                .foregroundColor(.black
                    .opacity(0.8))
                .padding(.top, 20)
            
            Text("Scanning will start automatically")
                .font(.callout)
                .foregroundColor(.gray)
            
            Spacer(minLength: 0)
            
            /// Scanner
            GeometryReader {
                let size = $0.size
                
                ZStack {
                    CameraView(frameSize: CGSize(width: size.width, height: size.width), session: $session)
                    /// Making it little smaller
                        .scaleEffect(0.97)
                    
                    ForEach(0...4,id: \.self) { index in
                        let rotation = Double(index) * 90
                        
                        RoundedRectangle(cornerRadius: 2, style: .circular)
                        ///Trimming to get Scanner like Edges
                            .trim(from: 0.61, to: 0.64)
                            .stroke(Color("Blue"), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                            .rotationEffect(.init(degrees: rotation))
                    }
                }
                /// Sqaure Shape
                .frame(width: size.width, height: size.width)
                /// Scanner Animation
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color("Blue"))
                        .frame(height: 2.5)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: isScanning ? 15 : -15 )
                        .offset(y: isScanning ? size.width : 0)
                }
                /// To Make it Center
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 45)

            Spacer(minLength: 15)
            
            Button {
                if !session.isRunning && cameraPermission == .approved {
                    reactiveCamera()
                    activateScannerAnimation()
                }
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
            
            Spacer(minLength: 45)

        }
        .padding(15)
        /// Checking Camera Permission, when the View is Visible
        .onAppear(perform: checkCameraPermission)
        .alert(errorMessage, isPresented: $showError) {
         /// Showing Setting's Button, if permission is denied
            if cameraPermission == .denied {
                Button("Settings") {
                    let settingsString = UIApplication.openSettingsURLString
                    if let settingsURL = URL(string: settingsString) {
                        /// Opening App's Setting, Using openURL Swiftui API
                        openURL(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {
                }
            }
        }
        .onChange(of: qrDelegate.scannedCode) { newValue in
            if let code = newValue {
                scannedCode = code
                /// When the first code scan is available, immediately stop the camera.
                DispatchQueue.global(qos: .background).async {
                    session.stopRunning()
                }
                ///Stopping Scanner Animation
                deActivateScannerAnimation()
                /// Clearing the Data on Delegate
                qrDelegate.scannedCode = nil
            }
        }
    }

    
    func reactiveCamera() {
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }
    
    /// Activating Scanner Animation Method
    func activateScannerAnimation() {
        /// Adding Delay for Each Reversal
        withAnimation(.easeInOut(duration: 0.85).delay(0.1).repeatForever(autoreverses: true)) {
            isScanning = true
        }
    }
    
    /// De-Activating Scanner Animation Method
    func deActivateScannerAnimation() {
        /// Adding Delay for Each Reversal
        withAnimation(.easeInOut(duration: 0.85)) {
            isScanning = false
        }
    }
    
    /// Checking Camera Permission
    func checkCameraPermission() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraPermission = .approved
                if session.inputs.isEmpty {
                    /// New Setup
                    setupCamera()
                } else {
                    /// Already Existing One
                    session.startRunning()
                }
            case .notDetermined:
                /// Requestiong Camera Access
                if await AVCaptureDevice.requestAccess(for: .video) {
                    /// Permission Granted
                    cameraPermission = .approved
                    setupCamera()
                } else {
                    /// Permission Denied
                    cameraPermission = .denied
                    /// Present Error Message
                    presentError("Please Provide Access to Camera for scanning codes")
                }
            case . denied, .restricted:
                cameraPermission = .denied
                presentError("Please Provide Access to Camera for scanning codes")
            default: break
            }
        }
    }
    
    /// Setting Up Camera
    func setupCamera() {
        do {
            /// Finding Back Camera
            guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera], mediaType: .video, position: .back).devices.first else {
                presentError("UNKNOWN DEVICE ERROR")
                return
            }
            
            /// Camera Input   
            let input = try AVCaptureDeviceInput(device: device)
            /// For Extra Saftey
            /// Checking Whether input & output can be added to the session
            guard session.canAddInput(input), session.canAddOutput(qrOutput) else {
                presentError("UNKNOWN INPUT/OUTPUT ERROR")
                return
            }
            
            /// Adding Input & output to Camera Session
            session.beginConfiguration()
            session.addInput(input)
            session.addOutput(qrOutput)
            /// Setting Output config to read QR codes
            qrOutput.metadataObjectTypes = [.qr]
            /// Adding Delegate to Retreive the Retched QR Code From Camera
            qrOutput.setMetadataObjectsDelegate(qrDelegate, queue: .main)
            session.commitConfiguration()
            /// Note Session must be started on Background thread
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
            activateScannerAnimation()
        } catch {
            presentError(error.localizedDescription)
        }
    }
    
    /// Presenting Error
    func presentError(_ message: String) {
        errorMessage = message
        showError.toggle()
    }
}
#Preview {
    ScannerView()
}

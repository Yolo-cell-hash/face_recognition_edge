package com.gnb.cam_widget

import android.app.KeyguardManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set lock screen display flags BEFORE super.onCreate for best results
        setupLockScreenFlags()
        
        // Handle keyguard dismissal based on how the activity was launched
        dismissKeyguardIfNeeded()
    }
    
    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Modern API (Android 8.1+)
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        
        // Also set window flags for comprehensive coverage
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }
    
    private fun dismissKeyguardIfNeeded() {
        val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        
        // Check if we're launching from the secure camera intent or widget
        val isSecureCamera = intent?.action == "android.media.action.STILL_IMAGE_CAMERA_SECURE"
        val isFromWidget = intent?.getBooleanExtra("launched_from_widget", false) == true
        
        if (isSecureCamera || isFromWidget) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                // Request keyguard dismissal - this allows the activity to show without PIN
                // The null callback means we don't care about the result
                keyguardManager.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        // Keyguard dismissed, camera is now accessible
                    }
                    
                    override fun onDismissCancelled() {
                        // User cancelled or dismissal failed - app still shows above lock screen
                    }
                    
                    override fun onDismissError() {
                        // Error occurred - app still shows above lock screen
                    }
                })
            } else {
                // For older devices, use deprecated flags
                @Suppress("DEPRECATION")
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Ensure flags are set when resuming
        setupLockScreenFlags()
    }
}

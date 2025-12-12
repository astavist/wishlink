package com.astavist.wishlink

import android.content.Context
import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.astavist.wishlink.R
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private var nativeAdFactory: WishActivityNativeAdFactory? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeAdFactory = WishActivityNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "wishlinkActivity",
            nativeAdFactory
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "wishlinkActivity")
        nativeAdFactory = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

class WishActivityNativeAdFactory(private val inflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = inflater.inflate(R.layout.wish_native_ad, null) as NativeAdView

        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.mediaView = adView.findViewById(R.id.ad_media)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)
        adView.callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)

        val cardRoot = adView.findViewById<LinearLayout>(R.id.ad_card_root)
        val iconContainer = adView.findViewById<FrameLayout>(R.id.ad_icon_container)

        val isDark = (customOptions?.get("isDark") as? Boolean)
            ?: isNightMode(adView.context.resources.configuration)
        val context = adView.context

        val cardColor = ContextCompat.getColor(
            context,
            if (isDark) R.color.wish_native_card_dark else R.color.wish_native_card_light
        )
        val iconColor = ContextCompat.getColor(
            context,
            if (isDark) R.color.wish_native_icon_dark else R.color.wish_native_icon_light
        )
        val mediaColor = ContextCompat.getColor(
            context,
            if (isDark) R.color.wish_native_media_dark else R.color.wish_native_media_light
        )
        val headlineColor = ContextCompat.getColor(
            context,
            if (isDark) R.color.wish_native_text_primary_dark else R.color.wish_native_text_primary_light
        )
        val bodyColor = ContextCompat.getColor(
            context,
            if (isDark) R.color.wish_native_text_secondary_dark else R.color.wish_native_text_secondary_light
        )

        cardRoot.background = roundedRect(cardColor, 28f, context)
        iconContainer.background = circle(iconColor)
        adView.mediaView?.background = roundedRect(mediaColor, 20f, context)

        (adView.headlineView as TextView).apply {
            text = nativeAd.headline
            setTextColor(headlineColor)
        }

        val bodyView = adView.bodyView as TextView
        if (nativeAd.body == null) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.visibility = View.VISIBLE
            bodyView.text = nativeAd.body
            bodyView.setTextColor(bodyColor)
        }

        val advertiserView = adView.advertiserView as TextView
        if (nativeAd.advertiser == null) {
            advertiserView.visibility = View.GONE
        } else {
            advertiserView.visibility = View.VISIBLE
            advertiserView.text = nativeAd.advertiser
            advertiserView.setTextColor(headlineColor)
        }

        val iconView = adView.iconView as ImageView
        if (nativeAd.icon == null) {
            iconView.visibility = View.GONE
        } else {
            iconView.visibility = View.VISIBLE
            iconView.setImageDrawable(nativeAd.icon!!.drawable)
        }

        val ctaButton = adView.callToActionView as Button
        if (nativeAd.callToAction == null) {
            ctaButton.visibility = View.GONE
        } else {
            ctaButton.visibility = View.VISIBLE
            ctaButton.text = nativeAd.callToAction
        }

        adView.mediaView?.mediaContent = nativeAd.mediaContent
        adView.setNativeAd(nativeAd)
        return adView
    }

    private fun roundedRect(color: Int, radiusDp: Float, context: Context): GradientDrawable {
        val radiusPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            radiusDp,
            context.resources.displayMetrics
        )
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radiusPx
            setColor(color)
        }
    }

    private fun circle(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }
    }

    private fun isNightMode(configuration: Configuration): Boolean {
        val uiMode = configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return uiMode == Configuration.UI_MODE_NIGHT_YES
    }
}

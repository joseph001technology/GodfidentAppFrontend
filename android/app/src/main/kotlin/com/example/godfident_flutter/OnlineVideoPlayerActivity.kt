package com.example.godfident_flutter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.window.OnBackInvokedDispatcher
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * A calm, single-video viewer for Online videos.
 *
 * It shows ONE platform embed page (YouTube /embed, TikTok /embed/v2, Instagram .../embed/,
 * Facebook video plugin, Vimeo player) in a WebView, with a Back button that returns to Godfident
 * and an "Open original" button. There is no address bar, no tabs and no way to wander: any link
 * that leaves the platform's own domains is opened outside (in the browser / the platform's app)
 * and never navigated to here. Nothing is queued after the video; when it ends, it ends.
 *
 * Honest limits: the embed page is the platform's own and may show ITS controls and suggestions;
 * private, removed, age-restricted or embedding-disabled videos fail inside the player, which this
 * screen cannot detect. That is why "Open original" is always one tap away.
 *
 * Not used for videos stored on the phone (those keep their own player).
 */
class OnlineVideoPlayerActivity : Activity() {

    companion object {
        const val EXTRA_EMBED = "embed_url"
        const val EXTRA_URL = "original_url"
        const val EXTRA_TITLE = "title"
        const val EXTRA_PLATFORM = "platform"
        private const val SLOW_MS = 20_000L

        /** Pages the viewer may stay on. Anything else is handed to the browser instead. */
        private val ALLOWED = listOf(
            "youtube.com", "youtube-nocookie.com", "ytimg.com", "googlevideo.com", "google.com", "gstatic.com",
            "instagram.com", "cdninstagram.com", "facebook.com", "fbcdn.net",
            "tiktok.com", "tiktokv.com", "tiktokcdn.com", "tiktokcdn-us.com",
            "vimeo.com", "vimeocdn.com"
        )

        fun allowedHost(host: String?): Boolean {
            val h = (host ?: return false).lowercase()
            return ALLOWED.any { h == it || h.endsWith(".$it") }
        }
    }

    private lateinit var frame: FrameLayout
    private lateinit var column: LinearLayout
    private lateinit var web: WebView
    private lateinit var footer: LinearLayout
    private lateinit var statusText: TextView
    private lateinit var fallbackBtn: Button

    private var original = ""
    private var platform = ""
    private var customView: View? = null
    private var customCallback: WebChromeClient.CustomViewCallback? = null
    private var failed = false
    private val handler = Handler(Looper.getMainLooper())

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val embed = intent.getStringExtra(EXTRA_EMBED) ?: ""
        original = intent.getStringExtra(EXTRA_URL) ?: embed
        platform = intent.getStringExtra(EXTRA_PLATFORM) ?: ""
        val title = intent.getStringExtra(EXTRA_TITLE) ?: ""

        val embedUri = Uri.parse(embed)
        if (embedUri.scheme != "https" || !allowedHost(embedUri.host)) {
            // Never load anything that is not one of the known embed pages.
            finish()
            return
        }

        buildUi(title)
        setupWebView()
        registerBack()

        statusText.text = "Opening from ${platform.ifEmpty { "the web" }}…"
        // YouTube's embedded player requires to know which app embeds it (Referer), otherwise it can
        // answer "Video player configuration error". Only sent to YouTube.
        val headers = HashMap<String, String>()
        val host = embedUri.host ?: ""
        if (host.endsWith("youtube.com") || host.endsWith("youtube-nocookie.com")) {
            headers["Referer"] = "https://$packageName"
        }
        web.loadUrl(embed, headers)

        handler.postDelayed({
            if (!isFinishing && footer.visibility == View.VISIBLE && !failed) {
                statusText.text = "Still loading… If nothing appears, open it in ${platform.ifEmpty { "the browser" }}."
                fallbackBtn.visibility = View.VISIBLE
            }
        }, SLOW_MS)
    }

    // ───────────── layout (built in code: no resource files needed) ─────────────

    private fun buildUi(title: String) {
        frame = FrameLayout(this)
        frame.setBackgroundColor(Color.parseColor("#121212"))
        // Edge-to-edge is on by default on current Android: keep the bar out from under the status bar.
        frame.setOnApplyWindowInsetsListener { v, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val b = insets.getInsets(WindowInsets.Type.systemBars())
                v.setPadding(b.left, b.top, b.right, b.bottom)
            } else {
                @Suppress("DEPRECATION")
                v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }

        column = LinearLayout(this)
        column.orientation = LinearLayout.VERTICAL

        // Top bar: Back · title · Open original
        val bar = LinearLayout(this)
        bar.orientation = LinearLayout.HORIZONTAL
        bar.gravity = Gravity.CENTER_VERTICAL
        bar.setBackgroundColor(Color.parseColor("#181818"))
        bar.minimumHeight = dp(52)

        val back = TextView(this)
        back.text = "← Back"
        back.setTextColor(Color.WHITE)
        back.textSize = 15f
        back.setTypeface(back.typeface, Typeface.BOLD)
        back.setPadding(dp(16), dp(14), dp(12), dp(14))
        back.setOnClickListener { handleBack() }

        val titleView = TextView(this)
        titleView.text = title
        titleView.setTextColor(Color.parseColor("#B3B3B3"))
        titleView.textSize = 13f
        titleView.maxLines = 1
        titleView.ellipsize = TextUtils.TruncateAt.END
        titleView.gravity = Gravity.CENTER_VERTICAL

        val openOriginal = TextView(this)
        openOriginal.text = "Open original"
        openOriginal.setTextColor(Color.parseColor("#D9B36C"))
        openOriginal.textSize = 13f
        openOriginal.setPadding(dp(12), dp(14), dp(16), dp(14))
        openOriginal.setOnClickListener { openOutside(original) }

        bar.addView(back, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        bar.addView(titleView, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        bar.addView(openOriginal, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        column.addView(bar, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        web = WebView(this)
        web.setBackgroundColor(Color.BLACK)
        column.addView(web, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        // Footer: "Opening..." while loading; a message + a button if it does not work.
        footer = LinearLayout(this)
        footer.orientation = LinearLayout.VERTICAL
        footer.setBackgroundColor(Color.parseColor("#181818"))
        footer.setPadding(dp(16), dp(10), dp(16), dp(10))
        statusText = TextView(this)
        statusText.setTextColor(Color.parseColor("#B3B3B3"))
        statusText.textSize = 13f
        fallbackBtn = Button(this)
        fallbackBtn.text = "Open in ${platform.ifEmpty { "browser" }}"
        fallbackBtn.visibility = View.GONE
        fallbackBtn.setOnClickListener { openOutside(original) }
        footer.addView(statusText)
        footer.addView(fallbackBtn)
        column.addView(footer, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        frame.addView(column, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        setContentView(frame)
    }

    private fun setupWebView() {
        val s = web.settings
        s.javaScriptEnabled = true // the platforms' embedded players are scripts
        s.domStorageEnabled = true
        s.mediaPlaybackRequiresUserGesture = false // the person already chose this video: it may start
        s.allowFileAccess = false
        s.allowContentAccess = false
        s.setSupportMultipleWindows(false)
        s.javaScriptCanOpenWindowsAutomatically = false
        s.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        try { CookieManager.getInstance().setAcceptThirdPartyCookies(web, true) } catch (_: Exception) {}

        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val r = request ?: return true
                val u = r.url
                if (u.scheme == "https" && allowedHost(u.host)) return false
                // A tapped link that leaves the platform goes to the browser; the viewer never navigates away.
                if (r.isForMainFrame && r.hasGesture()) openOutside(u.toString())
                return true
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                if (!failed) footer.visibility = View.GONE
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                if (request?.isForMainFrame == true) problem("This video could not be loaded. Check your connection.")
            }

            override fun onReceivedHttpError(view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?) {
                if (request?.isForMainFrame == true && (errorResponse?.statusCode ?: 0) >= 400) {
                    problem("${platform.ifEmpty { "The site" }} did not allow this video to play here.")
                }
            }
        }

        // Fullscreen button inside the platforms' players.
        web.webChromeClient = object : WebChromeClient() {
            override fun onShowCustomView(view: View?, callback: CustomViewCallback?) {
                if (view == null) {
                    callback?.onCustomViewHidden()
                    return
                }
                customView?.let { hideCustom() }
                customView = view
                customCallback = callback
                view.setBackgroundColor(Color.BLACK)
                frame.addView(view, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
                column.visibility = View.GONE
            }

            override fun onHideCustomView() {
                hideCustom()
            }
        }
    }

    private fun hideCustom() {
        val v = customView ?: return
        frame.removeView(v)
        customView = null
        column.visibility = View.VISIBLE
        try { customCallback?.onCustomViewHidden() } catch (_: Exception) {}
        customCallback = null
    }

    private fun problem(message: String) {
        failed = true
        footer.visibility = View.VISIBLE
        statusText.text = message
        fallbackBtn.visibility = View.VISIBLE
    }

    /** The platform's own app, or the browser. Always possible; the viewer stays open underneath. */
    private fun openOutside(url: String) {
        try {
            val i = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            startActivity(i)
        } catch (_: ActivityNotFoundException) {
            statusText.text = "No app can open this link."
            footer.visibility = View.VISIBLE
        } catch (_: Exception) {}
    }

    // ───────────── back / lifecycle ─────────────

    private fun registerBack() {
        // Android 13+ "predictive back" no longer calls onBackPressed for the gesture.
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { handleBack() }
        }
    }

    /** Fullscreen video: leave fullscreen first. Otherwise return to Godfident. */
    private fun handleBack() {
        if (customView != null) hideCustom() else finish()
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        handleBack()
    }

    override fun onPause() {
        super.onPause()
        if (::web.isInitialized) web.onPause() // stops the video when the person leaves
    }

    override fun onResume() {
        super.onResume()
        if (::web.isInitialized) web.onResume()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (::web.isInitialized) {
            try {
                (web.parent as? ViewGroup)?.removeView(web)
                web.stopLoading()
                web.loadUrl("about:blank")
                web.destroy()
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }
}

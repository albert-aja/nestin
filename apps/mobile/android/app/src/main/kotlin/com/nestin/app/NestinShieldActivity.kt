package com.nestin.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Native intervention screen displayed by [NestinAppShieldService] or the
 * foreground watcher when a user opens an app paused in Seren's Break the Cycle
 * (`BTC-02` Mindful App Pause) or restricted by Roo's App Fast / Focus Lock / Usage Limits.
 *
 * - For **Seren Break the Cycle (`btc_mindful_pause`)**: Displays Seren's calming
 *   lavender warning card with the user's *"My Why"*, an active 3–5 second intention
 *   countdown before unlocking *"I have a clear purpose — Continue"* (with zero guilt
 *   or failure penalty), a 1-tap *"Step Back — Open Urge Support in Nestin"* button,
 *   *"Go to Home Screen"*, and *"Snooze Mindful Pause for 1 hour"* (or complete block
 *   when `strictBlockMode` is enabled).
 * - For **Roo Digital Discipline (`roo_discipline`)**: Enforces Reminder Mode (5m grace)
 *   or Strict Mode.
 */
class NestinShieldActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "packageName"
        const val EXTRA_APP_NAME = "appName"
        const val EXTRA_INTERVENTION_KIND = "interventionKind"
        const val EXTRA_SOURCE_LABEL = "sourceLabel"
        const val EXTRA_TITLE = "title"
        const val EXTRA_REASON = "reason"
        const val EXTRA_MOTIVATION = "motivation"
        const val EXTRA_CAN_CONTINUE = "canContinue"
        const val EXTRA_PAUSE_SECONDS = "pauseDurationSeconds"
        const val EXTRA_GRACE_MINUTES = "cooldownGraceMinutes"
    }

    private var canContinue = false
    private var targetPackage = ""
    private var interventionKind = "roo_discipline"
    private var pauseSecondsLeft = 0
    private var graceMinutes = 5
    private val countdownHandler = Handler(Looper.getMainLooper())
    private var countdownRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        renderFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            renderFromIntent(intent)
        }
    }

    override fun onDestroy() {
        stopCountdown()
        super.onDestroy()
    }

    private fun stopCountdown() {
        countdownRunnable?.let { countdownHandler.removeCallbacks(it) }
        countdownRunnable = null
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Never allow system Back to pop straight back into a paused/restricted app.
        goHome()
    }

    private fun renderFromIntent(intent: Intent) {
        stopCountdown()
        targetPackage = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: ""
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: targetPackage
        interventionKind = intent.getStringExtra(EXTRA_INTERVENTION_KIND) ?: "roo_discipline"
        val isBtc = interventionKind == "btc_mindful_pause"
        val sourceLabel = intent.getStringExtra(EXTRA_SOURCE_LABEL)
            ?: if (isBtc) "Break the Cycle • Mindful App Pause" else "Roo Digital Discipline"
        val ruleTitle = intent.getStringExtra(EXTRA_TITLE)
            ?: if (isBtc) "Mindful Pause Check-In" else "Restriction Active"
        val reason = intent.getStringExtra(EXTRA_REASON)
            ?: if (isBtc) {
                "Take one gentle breath before stepping in. Does opening this right now support how you want to feel?"
            } else {
                "This app is currently restricted by Roo."
            }
        val motivation = intent.getStringExtra(EXTRA_MOTIVATION) ?: ""
        canContinue = intent.getBooleanExtra(EXTRA_CAN_CONTINUE, false)
        pauseSecondsLeft = if (canContinue) {
            intent.getIntExtra(EXTRA_PAUSE_SECONDS, if (isBtc) 4 else 0).coerceAtLeast(0)
        } else {
            0
        }
        graceMinutes = intent.getIntExtra(EXTRA_GRACE_MINUTES, if (isBtc) 15 else 5).coerceAtLeast(1)

        val primaryAccentHex = if (isBtc) {
            "#8B5CF6"
        } else if (canContinue) {
            "#F59E0B"
        } else {
            "#E04A3A"
        }
        val badgeTextHex = if (isBtc) {
            "#A78BFA"
        } else if (canContinue) {
            "#FBBF24"
        } else {
            "#FF6B5B"
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#111215"))
            setPadding(56, 72, 56, 72)
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 52, 48, 52)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1A1B20"))
                cornerRadius = 36f
                setStroke(2, Color.parseColor(primaryAccentHex))
            }
        }

        val mascotPrefix = if (isBtc) "SEREN" else "ROO"
        val badge = TextView(this).apply {
            text = "$mascotPrefix · ${sourceLabel.uppercase()}"
            textSize = 11f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor(badgeTextHex))
        }

        val heading = TextView(this).apply {
            text = "$appName is paused"
            textSize = 23f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor("#F1F3F5"))
            setPadding(0, 16, 0, 8)
        }

        val subHeading = TextView(this).apply {
            text = ruleTitle
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor("#CBD5E1"))
            setPadding(0, 0, 0, 10)
        }

        val body = TextView(this).apply {
            text = reason
            textSize = 14f
            setTextColor(Color.parseColor("#9CA3AF"))
            setPadding(0, 0, 0, 16)
        }

        card.addView(badge)
        card.addView(heading)
        card.addView(subHeading)
        card.addView(body)

        if (motivation.isNotBlank()) {
            val quoteText = if (isBtc) "Remember your Why:\n“$motivation”" else "“$motivation”"
            val quoteView = TextView(this).apply {
                text = quoteText
                textSize = 13f
                setTypeface(typeface, Typeface.ITALIC)
                setTextColor(Color.parseColor(if (isBtc) "#DDD6FE" else "#FDE68A"))
                setPadding(24, 18, 24, 18)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#252834"))
                    cornerRadius = 20f
                    if (isBtc) {
                        setStroke(1, Color.parseColor("#6D28D9"))
                    }
                }
            }
            val quoteParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
            card.addView(quoteView, quoteParams)
        }

        val modeNote = TextView(this).apply {
            text = if (isBtc) {
                if (canContinue) {
                    "Mindful Pause · Zero URL/content inspection and zero guilt counters. Step back for support or continue after a brief breath."
                } else {
                    "Strict Pause Active · Opening $appName is blocked while Break the Cycle Strict Block is enabled."
                }
            } else if (canContinue) {
                "Reminder Mode · Pause for a breath, return to Nestin, or continue if intentional."
            } else {
                "Strict Mode · Active until schedule/timer ends or you change the rule in Nestin."
            }
            textSize = 12f
            setTextColor(Color.parseColor("#6B7280"))
            setPadding(0, 0, 0, 24)
        }
        card.addView(modeNote)

        val returnBtn = Button(this).apply {
            text = if (isBtc) "Step Back — Open Urge Support in Nestin" else "Return to Nestin"
            isAllCaps = false
            textSize = 14.5f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor(if (isBtc) "#8B5CF6" else "#E04A3A"))
                cornerRadius = 24f
            }
            setOnClickListener {
                if (isBtc) {
                    recordBtcStepBackAndOpenSupport()
                } else {
                    openNestin()
                }
            }
        }
        card.addView(
            returnBtn,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 12 }
        )

        val homeBtn = Button(this).apply {
            text = "Go to Home Screen"
            isAllCaps = false
            textSize = 14f
            setTextColor(Color.parseColor("#E5E7EB"))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#252834"))
                cornerRadius = 24f
            }
            setOnClickListener { goHome() }
        }
        card.addView(
            homeBtn,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = if (canContinue) 12 else 0 }
        )

        if (canContinue) {
            val continueBtn = Button(this).apply {
                isAllCaps = false
                textSize = 13f
                background = GradientDrawable().apply {
                    setColor(Color.TRANSPARENT)
                    cornerRadius = 24f
                    setStroke(2, Color.parseColor(if (isBtc) "#7C3AED" else "#4B5563"))
                }
                setOnClickListener {
                    if (pauseSecondsLeft > 0) return@setOnClickListener
                    if (targetPackage.isNotBlank()) {
                        val prefs = applicationContext.getSharedPreferences(
                            NestinAppShieldService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        if (isBtc) {
                            val until = System.currentTimeMillis() + (graceMinutes * 60_000L)
                            prefs.edit()
                                .putLong("${NestinAppShieldService.KEY_BTC_GRACE_PREFIX}$targetPackage", until)
                                .apply()
                        } else {
                            val until = System.currentTimeMillis() + NestinAppShieldService.REMINDER_GRACE_MS
                            prefs.edit()
                                .putLong("${NestinAppShieldService.KEY_GRACE_PREFIX}$targetPackage", until)
                                .putLong("bypassed_at_$targetPackage", System.currentTimeMillis())
                                .apply()
                        }
                    }
                    finish()
                }
            }

            fun updateContinueButtonLabel() {
                if (pauseSecondsLeft > 0) {
                    continueBtn.isEnabled = false
                    continueBtn.setTextColor(Color.parseColor("#6B7280"))
                    continueBtn.text = if (isBtc) {
                        "I have a clear purpose — Continue (${pauseSecondsLeft}s)"
                    } else {
                        "Continue to $appName (${pauseSecondsLeft}s)"
                    }
                } else {
                    continueBtn.isEnabled = true
                    continueBtn.setTextColor(Color.parseColor(if (isBtc) "#C4B5FD" else "#FBBF24"))
                    continueBtn.text = if (isBtc) {
                        "I have a clear purpose — Continue (${graceMinutes}m grace)"
                    } else {
                        "Continue to $appName (5 min)"
                    }
                }
            }

            updateContinueButtonLabel()
            card.addView(
                continueBtn,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = if (isBtc) 10 else 0 }
            )

            if (pauseSecondsLeft > 0) {
                val runnable = object : Runnable {
                    override fun run() {
                        if (isFinishing || isDestroyed) return
                        pauseSecondsLeft = (pauseSecondsLeft - 1).coerceAtLeast(0)
                        updateContinueButtonLabel()
                        if (pauseSecondsLeft > 0) {
                            countdownHandler.postDelayed(this, 1000L)
                        }
                    }
                }
                countdownRunnable = runnable
                countdownHandler.postDelayed(runnable, 1000L)
            }

            if (isBtc) {
                val snoozeBtn = Button(this).apply {
                    text = "Snooze Mindful Pause for 1 hour"
                    isAllCaps = false
                    textSize = 12f
                    setTextColor(Color.parseColor("#9CA3AF"))
                    background = GradientDrawable().apply {
                        setColor(Color.TRANSPARENT)
                        cornerRadius = 20f
                    }
                    setOnClickListener {
                        val prefs = applicationContext.getSharedPreferences(
                            NestinAppShieldService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        val until = System.currentTimeMillis() + 3600_000L
                        prefs.edit()
                            .putLong(NestinAppShieldService.KEY_BTC_SNOOZED_UNTIL_MS, until)
                            .apply()
                        finish()
                    }
                }
                card.addView(
                    snoozeBtn,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                )
            }
        } else {
            val spacer = View(this)
            card.addView(spacer)
        }

        root.addView(
            card,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        setContentView(root)
    }

    private fun recordBtcStepBackAndOpenSupport() {
        val prefs = applicationContext.getSharedPreferences(
            NestinAppShieldService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val prev = prefs.getInt(NestinAppShieldService.KEY_BTC_STEP_BACK_COUNT, 0)
        prefs.edit().putInt(NestinAppShieldService.KEY_BTC_STEP_BACK_COUNT, prev + 1).apply()

        val deepLinkIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("nestin://mental_wellness?layer=3&urge_support=1&pkg=$targetPackage")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        try {
            startActivity(deepLinkIntent)
        } catch (_: Exception) {
            openNestin()
            return
        }
        finish()
    }

    private fun openNestin() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
        finish()
    }

    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(homeIntent)
        finish()
    }
}

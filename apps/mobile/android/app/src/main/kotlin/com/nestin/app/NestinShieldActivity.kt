package com.nestin.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Native intervention screen displayed by [NestinAppShieldService] when a user
 * opens an app restricted by App Fast, Focus Lock, or Daily Usage Limits.
 *
 * Reminder Mode includes a "Continue Anyway (5 min)" option recording temporary
 * grace; Strict Mode offers only leaving the app ("Return to Nestin" / Home).
 */
class NestinShieldActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "packageName"
        const val EXTRA_APP_NAME = "appName"
        const val EXTRA_SOURCE_LABEL = "sourceLabel"
        const val EXTRA_TITLE = "title"
        const val EXTRA_REASON = "reason"
        const val EXTRA_MOTIVATION = "motivation"
        const val EXTRA_CAN_CONTINUE = "canContinue"
    }

    private var canContinue = false
    private var targetPackage = ""

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

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Never allow system Back to pop straight back into a strictly restricted app.
        goHome()
    }

    private fun renderFromIntent(intent: Intent) {
        targetPackage = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: ""
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: targetPackage
        val sourceLabel = intent.getStringExtra(EXTRA_SOURCE_LABEL) ?: "Roo Digital Discipline"
        val ruleTitle = intent.getStringExtra(EXTRA_TITLE) ?: "Restriction Active"
        val reason = intent.getStringExtra(EXTRA_REASON) ?: "This app is currently restricted by Roo."
        val motivation = intent.getStringExtra(EXTRA_MOTIVATION) ?: ""
        canContinue = intent.getBooleanExtra(EXTRA_CAN_CONTINUE, false)

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
                setStroke(2, Color.parseColor(if (canContinue) "#F59E0B" else "#E04A3A"))
            }
        }

        val badge = TextView(this).apply {
            text = "ROO · ${sourceLabel.uppercase()}"
            textSize = 11f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor(if (canContinue) "#FBBF24" else "#FF6B5B"))
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
            val quoteView = TextView(this).apply {
                text = "“$motivation”"
                textSize = 13f
                setTypeface(typeface, Typeface.ITALIC)
                setTextColor(Color.parseColor("#FDE68A"))
                setPadding(24, 18, 24, 18)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#252834"))
                    cornerRadius = 20f
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
            text = if (canContinue) {
                "Reminder Mode · Pause for a breath, return to Nestin, or continue if intentional."
            } else {
                "Strict Mode · Active until schedule/timer ends or you change the rule in Nestin."
            }
            textSize = 12f
            setTextColor(Color.parseColor("#6B7280"))
            setPadding(0, 0, 0, 28)
        }
        card.addView(modeNote)

        val returnBtn = Button(this).apply {
            text = "Return to Nestin"
            isAllCaps = false
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E04A3A"))
                cornerRadius = 24f
            }
            setOnClickListener { openNestin() }
        }
        card.addView(
            returnBtn,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 14 }
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
            ).apply { bottomMargin = if (canContinue) 14 else 0 }
        )

        if (canContinue) {
            val continueBtn = Button(this).apply {
                text = "Continue to $appName (5 min)"
                isAllCaps = false
                textSize = 13f
                setTextColor(Color.parseColor("#FBBF24"))
                background = GradientDrawable().apply {
                    setColor(Color.TRANSPARENT)
                    cornerRadius = 24f
                    setStroke(2, Color.parseColor("#4B5563"))
                }
                setOnClickListener {
                    if (targetPackage.isNotBlank()) {
                        val prefs = applicationContext.getSharedPreferences(
                            NestinAppShieldService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        val until = System.currentTimeMillis() + NestinAppShieldService.REMINDER_GRACE_MS
                        prefs.edit()
                            .putLong("${NestinAppShieldService.KEY_GRACE_PREFIX}$targetPackage", until)
                            .putLong("bypassed_at_$targetPackage", System.currentTimeMillis())
                            .apply()
                    }
                    finish()
                }
            }
            card.addView(
                continueBtn,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
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

package com.seanw94.poc

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

// Deliberately dependency-free (no AndroidX, no Compose): the point of this
// POC is proving the phone -> GitHub Actions -> APK loop, not the UI stack.
class MainActivity : Activity() {

    private val phrases = listOf(
        "こんにちは！" to "Hello!",
        "おつかれさま！" to "Good work!",
        "いってきます！" to "I'm off!",
        "ただいま！" to "I'm home!",
        "いただきます！" to "Let's eat!",
        "おやすみなさい。" to "Good night.",
    )
    private var taps = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val ja = TextView(this).apply {
            textSize = 42f
            setTextColor(Color.parseColor("#16264A"))
            gravity = Gravity.CENTER
            text = "たぬき"
        }
        val en = TextView(this).apply {
            textSize = 20f
            setTextColor(Color.parseColor("#6D7B90"))
            gravity = Gravity.CENTER
            text = "Built by GitHub Actions"
        }
        val count = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.parseColor("#2E93A7"))
            gravity = Gravity.CENTER
        }
        val button = Button(this).apply {
            text = "タップ"
            textSize = 22f
            setOnClickListener {
                taps++
                val (j, e) = phrases[taps % phrases.size]
                ja.text = j
                en.text = e
                count.text = "taps: $taps"
            }
        }

        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#FFF8EC"))
            setPadding(48, 48, 48, 48)
            addView(ja)
            addView(en)
            addView(button, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = 64; gravity = Gravity.CENTER })
            addView(count)
        })
    }
}

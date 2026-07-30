package com.biohelix.app

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "BHRC fitness data privacy"

        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(Color.WHITE)
            addView(TextView(context).apply {
                text = "How BHRC uses fitness data"
                textSize = 24f
                setTextColor(Color.rgb(6, 72, 155))
            })
            addView(TextView(context).apply {
                text = """

                    With your permission, BHRC reads daily steps, active calories and distance from Health Connect.

                    We send only daily totals to your authenticated BHRC patient profile to calculate a wellness activity score and award eligible MyClub points. We do not use this data for advertising, diagnosis, insurance decisions or unrelated profiling.

                    Fitness data is linked only to the patient who explicitly connects this phone. Switching to a relative does not transfer or sync the phone owner’s activity.

                    You can disconnect BHRC or revoke individual permissions at any time in Health Connect settings. Activity scores are wellness indicators and are not medical advice.
                """.trimIndent()
                textSize = 16f
                setTextColor(Color.DKGRAY)
                setLineSpacing(0f, 1.25f)
            })
        }

        setContentView(
            ScrollView(this).apply {
                addView(
                    content,
                    ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ),
                )
            },
        )
    }
}

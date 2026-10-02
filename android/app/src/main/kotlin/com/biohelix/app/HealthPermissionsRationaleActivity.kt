package com.biohelix.app

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.text.util.Linkify
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

                    Activity Rewards is optional. After you tap Connect activity and grant permission, BHRC reads only daily step totals from Health Connect. It does not read calories, distance or step cadence.

                    We send up to seven days of daily step totals, their dates and your timezone to BHRC servers, linked to your authenticated patient profile. These totals show progress toward your step goal, calculate a wellness activity score and award eligible MyClub points. Sync runs when you connect, when you reopen the app and when you refresh activity.

                    We do not use this data for advertising, diagnosis, insurance decisions or unrelated profiling. Activity scores are wellness indicators and are not medical advice.

                    Fitness data is linked only to the patient who explicitly connects this phone. Switching to a relative does not transfer or sync the phone owner’s activity.

                    To stop future syncing from this phone, open Activity Rewards, tap More activity options and choose Disconnect activity. This removes the phone's connection to your patient profile. It does not revoke the Health Connect permission or delete data on your phone or data already synced to BHRC servers. To revoke permission, use Health Connect settings.

                    Previously synced totals and reward records remain on BHRC servers until separately deleted; there is no automatic expiry in the current fitness service. Closing your portal account does not automatically delete these records. Contact BHRC through the Privacy Policy to request deletion and confirmation of how your request is handled.
                """.trimIndent()
                textSize = 16f
                setTextColor(Color.DKGRAY)
                setLineSpacing(0f, 1.25f)
            })
            addView(TextView(context).apply {
                text = "Privacy Policy: https://www.bhrchospital.com/privacy-policy"
                textSize = 16f
                setPadding(0, padding, 0, 0)
                Linkify.addLinks(this, Linkify.WEB_URLS)
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

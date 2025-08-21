package com.example.salat_time;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import android.os.SystemClock;
import android.text.format.DateUtils;
import android.widget.RemoteViews;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

// TODO: FIX WIDGET NEXT PRAYER LOGIC - Widget still showing wrong prayer (Fajr instead of current next prayer)
// Issues to investigate:
// 1. DateTime comparison logic may have timezone issues between Java and Dart
// 2. Prayer time parsing from API might be inconsistent 
// 3. Widget refresh timing may not be triggering properly
// 4. SharedPreferences keys might not be syncing between Flutter and Java
// 5. Background refresh thread may not be updating widget display correctly
// 6. Need to add more debug logging to trace exact prayer selection logic
// 7. Consider simplifying to use only Dart-side computation and Java just displays cached results
public class NextPrayerWidgetProvider extends AppWidgetProvider {

    private static final String PREFS_NAME = "HomeWidgetPreferences"; // used by home_widget plugin
    private static final String KEY_NAME = "widget_next_prayer_name";
    private static final String KEY_COUNTDOWN = "widget_next_prayer_countdown";
    private static final String KEY_EPOCH = "widget_next_prayer_epoch"; // string millis
    private static final String ACTION_TICK = "com.example.salat_time.ACTION_WIDGET_TICK";
    private static final String FLUTTER_PREFS = "FlutterSharedPreferences";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int widgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId);
        }
        scheduleNextTick(context);
    }

    @Override
    public void onEnabled(Context context) {
        scheduleNextTick(context);
    }

    @Override
    public void onDisabled(Context context) {
        cancelTick(context);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        String action = intent.getAction();
        if (ACTION_TICK.equals(action)
                || Intent.ACTION_TIME_TICK.equals(action)
                || Intent.ACTION_TIME_CHANGED.equals(action)
                || Intent.ACTION_TIMEZONE_CHANGED.equals(action)
                || Intent.ACTION_DATE_CHANGED.equals(action)
                || Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            AppWidgetManager mgr = AppWidgetManager.getInstance(context);
            int[] ids = mgr.getAppWidgetIds(new android.content.ComponentName(context, NextPrayerWidgetProvider.class));
            for (int id : ids) {
                updateAppWidget(context, mgr, id);
            }
            scheduleNextTick(context);
        }
    }

    private static void scheduleNextTick(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(context, NextPrayerWidgetProvider.class).setAction(ACTION_TICK);
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, i, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
        long triggerAt = SystemClock.elapsedRealtime() + DateUtils.MINUTE_IN_MILLIS; // in 1 minute
        if (am != null) {
            am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi);
        }
    }

    private static void cancelTick(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(context, NextPrayerWidgetProvider.class).setAction(ACTION_TICK);
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, i, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_CANCEL_CURRENT);
        if (am != null) {
            am.cancel(pi);
        }
    }

    public static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    String nextPrayer = prefs.getString(KEY_NAME, null);
    String countdownStored = prefs.getString(KEY_COUNTDOWN, null);
    String epochStr = prefs.getString(KEY_EPOCH, null);
    Log.d("Widget", "updateAppWidget: name=" + nextPrayer + " epoch=" + epochStr + " countdown=" + countdownStored);

        if (nextPrayer == null) nextPrayer = "-";

    String countdown = countdownStored;
        boolean needRefresh = false;
    if (epochStr != null) {
            try {
                long target = Long.parseLong(epochStr);
                long now = System.currentTimeMillis();
                long diff = Math.max(0, target - now);
                long hours = diff / (1000 * 60 * 60);
                long minutes = (diff / (1000 * 60)) % 60;
                long seconds = (diff / 1000) % 60;
                countdown = String.format("%02d:%02d:%02d", hours, minutes, seconds);
                // If we've hit zero, mark to refresh data on next tick
                if (diff == 0) {
                    needRefresh = true;
                }
            } catch (Exception ignored) { }
        } else {
            // No epoch stored; trigger a refresh
            needRefresh = true;
            Log.d("Widget", "No epoch stored; scheduling background refresh");
        }
        if (countdown == null) countdown = "--:--:--";

        // Heuristic: if it's showing Fajr as next but it's well into the day, force a refresh
        try {
            if ("Fajr".equalsIgnoreCase(nextPrayer)) {
                java.util.Calendar nowCal = java.util.Calendar.getInstance();
                int hour = nowCal.get(java.util.Calendar.HOUR_OF_DAY);
                // If it's between 8 AM and 11 PM and still showing Fajr, something is wrong
                if (hour >= 8 && hour <= 23) {
                    needRefresh = true;
                    Log.d("Widget", "Heuristic refresh: Showing Fajr during daytime");
                }
            }
        } catch (Exception ignored) {}

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_next_prayer);
        views.setTextViewText(R.id.tv_prayer_name, nextPrayer);
        views.setTextViewText(R.id.tv_countdown, countdown);

        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent != null) {
            PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.tv_title, pendingIntent);
            views.setOnClickPendingIntent(R.id.tv_prayer_name, pendingIntent);
            views.setOnClickPendingIntent(R.id.tv_countdown, pendingIntent);
        }

        appWidgetManager.updateAppWidget(appWidgetId, views);

        // If we need fresh data (epoch missing or expired), try to recompute in background
    if (needRefresh) {
            refreshDataInBackground(context, appWidgetManager, appWidgetId);
        }
    }

    private static void refreshDataInBackground(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        new Thread(() -> {
            try {
                SharedPreferences flutter = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE);
                String latStr = flutter.getString("flutter.lastLatitude", null);
                String lonStr = flutter.getString("flutter.lastLongitude", null);
                int method = flutter.getInt("flutter.calculationMethod", 2);
                if (latStr == null || lonStr == null) return;
                double lat = Double.parseDouble(latStr);
                double lon = Double.parseDouble(lonStr);
                Log.d("Widget", "refreshData: lat=" + lat + " lon=" + lon + " method=" + method);

                String perOffsetsJson = flutter.getString("flutter.perPrayerOffsets", null);
                Map<String, Integer> offsets = new HashMap<>();
                offsets.put("Fajr", 0);
                offsets.put("Dhuhr", 0);
                offsets.put("Asr", 0);
                offsets.put("Maghrib", 0);
                offsets.put("Isha", 0);
                if (perOffsetsJson != null) {
                    try {
                        JSONObject o = new JSONObject(perOffsetsJson);
                        for (String k : new String[]{"Fajr","Dhuhr","Asr","Maghrib","Isha"}) {
                            if (o.has(k)) {
                                try { offsets.put(k, o.getInt(k)); } catch (Exception e) {
                                    try { offsets.put(k, Integer.parseInt(o.getString(k))); } catch (Exception ignored) {}
                                }
                            }
                        }
                    } catch (Exception ignored) {}
                }

                String today = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
                String urlStr = String.format(Locale.US,
                        "https://api.aladhan.com/v1/timings/%s?latitude=%f&longitude=%f&method=%d",
                        today, lat, lon, method);
                URL url = new URL(urlStr);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestProperty("User-Agent", "SalatTimeApp/1.0");
                conn.setConnectTimeout(8000);
                conn.setReadTimeout(8000);
                int code = conn.getResponseCode();
                if (code != 200) return;
                BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
                br.close();
                JSONObject root = new JSONObject(sb.toString());
                if (root.optInt("code", 0) != 200) return;
                JSONObject timings = root.getJSONObject("data").getJSONObject("timings");

                // Compute next prayer among five with proper time comparison
                long nowMs = System.currentTimeMillis();
                Calendar cal = Calendar.getInstance();
                // Use current date as base for today's prayers
                cal.setTimeInMillis(nowMs);
                int currentYear = cal.get(Calendar.YEAR);
                int currentMonth = cal.get(Calendar.MONTH);
                int currentDay = cal.get(Calendar.DAY_OF_MONTH);
                
                long bestEpoch = -1; // UTC epoch millis
                String bestName = null;
                
                for (String p : new String[]{"Fajr","Dhuhr","Asr","Maghrib","Isha"}) {
                    if (!timings.has(p)) continue;
                    String t = timings.optString(p, null);
                    if (t == null) continue;
                    try {
                        String[] parts = t.split(":");
                        if (parts.length < 2) continue;
                        int h = Integer.parseInt(parts[0].replaceAll("[^0-9]", ""));
                        int m = Integer.parseInt(parts[1].replaceAll("[^0-9]", ""));
                        
                        Calendar prayerCal = Calendar.getInstance();
                        prayerCal.set(currentYear, currentMonth, currentDay, h, m, 0);
                        prayerCal.set(Calendar.MILLISECOND, 0);
                        
                        int off = offsets.get(p) != null ? offsets.get(p) : 0;
                        prayerCal.add(Calendar.MINUTE, off);
                        long epoch = prayerCal.getTimeInMillis(); // epoch is absolute UTC
                        
                        // Add 30 second buffer to avoid edge cases
                        if (epoch > (nowMs + 30000)) {
                            bestEpoch = epoch;
                            bestName = p;
                            break;
                        }
                    } catch (Exception ignored) {}
                }
                // If no prayer found today, next is tomorrow's Fajr
                if (bestName == null) {
                    String fajr = timings.optString("Fajr", null);
                    if (fajr != null) {
                        try {
                            String[] parts = fajr.split(":");
                            int h = Integer.parseInt(parts[0].replaceAll("[^0-9]", ""));
                            int m = Integer.parseInt(parts[1].replaceAll("[^0-9]", ""));
                            
                            Calendar tomorrowCal = Calendar.getInstance();
                            tomorrowCal.set(currentYear, currentMonth, currentDay + 1, h, m, 0);
                            tomorrowCal.set(Calendar.MILLISECOND, 0);
                            
                            int off = offsets.get("Fajr") != null ? offsets.get("Fajr") : 0;
                            tomorrowCal.add(Calendar.MINUTE, off);
                bestEpoch = tomorrowCal.getTimeInMillis();
                            bestName = "Fajr";
                        } catch (Exception ignored) {}
                    }
                }

                if (bestName != null && bestEpoch > 0) {
            Log.d("Widget", "Computed next: " + bestName + " at epoch=" + bestEpoch);
                    long diff = Math.max(0, bestEpoch - nowMs);
                    long hours = diff / (1000 * 60 * 60);
                    long minutes = (diff / (1000 * 60)) % 60;
                    long seconds = (diff / 1000) % 60;
                    String countdown = String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, seconds);

                    // Save to HomeWidgetPreferences so provider reads unified source
                    SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                    prefs.edit()
                        .putString(KEY_NAME, bestName)
                        .putString(KEY_COUNTDOWN, countdown)
                        .putString(KEY_EPOCH, Long.toString(bestEpoch))
                        .apply();
                    Log.d("Widget", "Saved prefs: name=" + bestName + " countdown=" + countdown + " epoch=" + bestEpoch);

                    // Render updated views now
                    RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_next_prayer);
                    views.setTextViewText(R.id.tv_prayer_name, bestName);
                    views.setTextViewText(R.id.tv_countdown, countdown);
                    appWidgetManager.updateAppWidget(appWidgetId, views);
                }
            } catch (Exception ignored) { }
        }).start();
    }
}

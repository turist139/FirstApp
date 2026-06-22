import SwiftUI
import SwiftData
import AVFoundation
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressQuery: [UserProgress]
    
    @AppStorage("detoxDayBoundaryHour", store: .shared) private var detoxDayBoundaryHour: Int = 0
    @AppStorage("notificationHour", store: .shared) private var notificationHour: Int = 21
    @AppStorage("notificationMinute", store: .shared) private var notificationMinute: Int = 0
    @AppStorage("customMantra", store: .shared) private var customMantra: String = "продержись всего сегодняшний день"
    
    @AppStorage("morningNotificationHour", store: .shared) private var morningNotificationHour: Int = 9
    @AppStorage("morningNotificationMinute", store: .shared) private var morningNotificationMinute: Int = 0
    
    @AppStorage("overrideEveningDate", store: .shared) private var overrideEveningDate: String = ""
    @AppStorage("overrideEveningHour", store: .shared) private var overrideEveningHour: Int = -1
    @AppStorage("overrideEveningMinute", store: .shared) private var overrideEveningMinute: Int = -1
    
    @AppStorage("overrideMorningDate", store: .shared) private var overrideMorningDate: String = ""
    @AppStorage("overrideMorningHour", store: .shared) private var overrideMorningHour: Int = -1
    @AppStorage("overrideMorningMinute", store: .shared) private var overrideMorningMinute: Int = -1
    
    @State private var notificationTime: Date = Date()
    @State private var morningNotificationTime: Date = Date()
    @State private var soundIDText: String = "1057"
    
    @State private var showEveningOverrideSheet = false
    @State private var showMorningOverrideSheet = false
    @State private var tempEveningOverrideTime: Date = Date()
    @State private var tempMorningOverrideTime: Date = Date()
    
    var progress: UserProgress {
        progressQuery.first ?? UserProgress()
    }
    
    // Maps ID to (Display Name, Filename)
    let commonSounds: [UInt32: (title: String, file: String)] = [
        1000: ("New Mail", "new-mail.caf"),
        1001: ("Mail Sent", "mail-sent.caf"),
        1002: ("Voicemail Received", "Voicemail.caf"),
        1003: ("SMS Received (Ding)", "ReceivedMessage.caf"),
        1004: ("SMS Sent (Swoosh)", "SentMessage.caf"),
        1005: ("Calendar Alert", "sq_alarm.caf"),
        1006: ("Low Power", "low_power.caf"),
        1007: ("SMS Received Alert 1", "sms-received1.caf"),
        1008: ("SMS Received Alert 2", "sms-received2.caf"),
        1009: ("SMS Received Alert 3", "sms-received3.caf"),
        1010: ("SMS Received Alert 4", "sms-received4.caf"),
        1012: ("SMS Received Alert 1", "sms-received1.caf"),
        1013: ("SMS Received Alert 5", "sms-received5.caf"),
        1014: ("SMS Received Alert 6", "sms-received6.caf"),
        1015: ("Voicemail", "Voicemail.caf"),
        1016: ("Tweet Sent", "tweet_sent.caf"),
        1020: ("Anticipate", "Anticipate.caf"),
        1021: ("Bloom", "Bloom.caf"),
        1022: ("Calypso", "Calypso.caf"),
        1023: ("Choo Choo", "Choo_Choo.caf"),
        1024: ("Descent", "Descent.caf"),
        1025: ("Fanfare", "Fanfare.caf"),
        1026: ("Ladder", "Ladder.caf"),
        1027: ("Minuet", "Minuet.caf"),
        1028: ("News Flash", "News_Flash.caf"),
        1029: ("Noir", "Noir.caf"),
        1030: ("Sherwood Forest", "Sherwood_Forest.caf"),
        1031: ("Spell", "Spell.caf"),
        1032: ("Suspense", "Suspense.caf"),
        1033: ("Telegraph", "Telegraph.caf"),
        1034: ("Tiptoes", "Tiptoes.caf"),
        1035: ("Typewriters", "Typewriters.caf"),
        1036: ("Update", "Update.caf"),
        1050: ("USSD Alert", "ussd.caf"),
        1051: ("SIM Toolkit Call Dropped", "SIMToolkitCallDropped.caf"),
        1052: ("SIM Toolkit General Beep", "SIMToolkitGeneralBeep.caf"),
        1053: ("SIM Toolkit Negative ACK", "SIMToolkitNegativeACK.caf"),
        1054: ("SIM Toolkit Positive ACK", "SIMToolkitPositiveACK.caf"),
        1055: ("SIM Toolkit SMS", "SIMToolkitSMS.caf"),
        1057: ("Tink", "Tink.caf"),
        1070: ("Audio Tone Busy", "ct-busy.caf"),
        1071: ("Audio Tone Congestion", "ct-congestion.caf"),
        1072: ("Audio Tone Path Ack", "ct-path-ack.caf"),
        1073: ("Audio Tone Error", "ct-error.caf"),
        1074: ("Audio Tone Call Waiting", "ct-call-waiting.caf"),
        1075: ("Audio Tone Key 2", "ct-keytone2.caf"),
        1100: ("Screen Locked", "sq_lock.caf"),
        1101: ("Screen Unlocked", "sq_lock.caf"),
        1103: ("Key Pressed (Tink)", "sq_tock.caf"),
        1104: ("Key Pressed (Tock)", "sq_tock.caf"),
        1105: ("Key Pressed (Tock)", "sq_tock.caf"),
        1106: ("Connected To Power", "sq_beep-beep.caf"),
        1107: ("Ringer Switch", "RingerChanged.caf"),
        1108: ("Camera Shutter", "photoShutter.caf"),
        1109: ("Shake To Shuffle", "shake.caf"),
        1110: ("JBL Begin", "jbl_begin.caf"),
        1111: ("JBL Confirm", "jbl_confirm.caf"),
        1112: ("JBL Cancel", "jbl_cancel.caf"),
        1113: ("Begin Recording", "begin_record.caf"),
        1114: ("End Recording", "end_record.caf"),
        1115: ("JBL Ambiguous", "jbl_ambiguous.caf"),
        1116: ("JBL No Match", "jbl_no_match.caf"),
        1117: ("Begin Video Recording", "begin_video_record.caf"),
        1118: ("End Video Recording", "end_video_record.caf"),
        1150: ("VC Invitation Accepted", "vc~invitation-accepted.caf"),
        1151: ("VC Ringing", "vc~ringing.caf"),
        1152: ("VC Ended", "vc~ended.caf"),
        1153: ("VC Call Waiting", "ct-call-waiting.caf"),
        1154: ("VC Call Upgrade", "vc~ringing.caf"),
        1200: ("Touch Tone 0", "dtmf-0.caf"),
        1201: ("Touch Tone 1", "dtmf-1.caf"),
        1202: ("Touch Tone 2", "dtmf-2.caf"),
        1203: ("Touch Tone 3", "dtmf-3.caf"),
        1204: ("Touch Tone 4", "dtmf-4.caf"),
        1205: ("Touch Tone 5", "dtmf-5.caf"),
        1206: ("Touch Tone 6", "dtmf-6.caf"),
        1207: ("Touch Tone 7", "dtmf-7.caf"),
        1208: ("Touch Tone 8", "dtmf-8.caf"),
        1209: ("Touch Tone 9", "dtmf-9.caf"),
        1210: ("Touch Tone Star", "dtmf-star.caf"),
        1211: ("Touch Tone Pound", "dtmf-pound.caf"),
        1254: ("Headset Start Call", "long_low_short_high.caf"),
        1255: ("Headset Redial", "short_double_high.caf"),
        1256: ("Headset Answer Call", "short_low_high.caf"),
        1257: ("Headset End Call", "short_double_low.caf"),
        1258: ("Headset Call Waiting Actions", "short_double_low.caf"),
        1259: ("Headset Transition End", "middle_9_short_double_low.caf"),
        1300: ("Preview (Voicemail)", "Voicemail.caf"),
        1301: ("Preview (Received Message)", "ReceivedMessage.caf"),
        1302: ("Preview (New Mail)", "new-mail.caf"),
        1303: ("Preview (Mail Sent)", "mail-sent.caf"),
        1304: ("Preview (Alarm)", "sq_alarm.caf"),
        1305: ("Preview (Lock)", "sq_lock.caf"),
        1306: ("Key Press Click Preview", "sq_tock.caf"),
        1307: ("SMS Selection 1", "sms-received1.caf"),
        1308: ("SMS Selection 2", "sms-received2.caf"),
        1309: ("SMS Selection 3", "sms-received3.caf"),
        1310: ("SMS Selection 4", "sms-received4.caf"),
        1312: ("SMS Selection 1", "sms-received1.caf"),
        1313: ("SMS Selection 5", "sms-received5.caf"),
        1314: ("SMS Selection 6", "sms-received6.caf"),
        1315: ("Preview (Voicemail)", "Voicemail.caf"),
        1320: ("Selection (Anticipate)", "Anticipate.caf"),
        1321: ("Selection (Bloom)", "Bloom.caf"),
        1322: ("Selection (Calypso)", "Calypso.caf"),
        1323: ("Selection (Choo Choo)", "Choo_Choo.caf"),
        1324: ("Selection (Descent)", "Descent.caf"),
        1325: ("Selection (Fanfare)", "Fanfare.caf"),
        1326: ("Selection (Ladder)", "Ladder.caf"),
        1327: ("Selection (Minuet)", "Minuet.caf"),
        1328: ("Selection (News Flash)", "News_Flash.caf"),
        1329: ("Selection (Noir)", "Noir.caf"),
        1330: ("Selection (Sherwood Forest)", "Sherwood_Forest.caf"),
        1331: ("Selection (Spell)", "Spell.caf"),
        1332: ("Selection (Suspense)", "Suspense.caf"),
        1333: ("Selection (Telegraph)", "Telegraph.caf"),
        1334: ("Selection (Tiptoes)", "Tiptoes.caf"),
        1335: ("Selection (Typewriters)", "Typewriters.caf"),
        1336: ("Selection (Update)", "Update.caf")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. Progress Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("УРОВЕНЬ И ДОСТИЖЕНИЯ")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        
                        NavigationLink(destination: ProgressionView()) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                
                                Text("Мой Прогресс")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. Settings Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("НАСТРОЙКИ ДЕТОКСА")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        
                        // Day boundary shift
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Когда заканчивается день?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Позволяет сдвинуть границу дня детокса. Полезно, если вы ложитесь спать после полуночи.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Picker("Конец дня", selection: $detoxDayBoundaryHour) {
                                Text("00:00 (Полночь)").tag(0)
                                Text("01:00 AM").tag(1)
                                Text("02:00 AM").tag(2)
                                Text("03:00 AM").tag(3)
                                Text("04:00 AM").tag(4)
                                Text("05:00 AM").tag(5)
                                Text("06:00 AM").tag(6)
                            }
                            .pickerStyle(.menu)
                            .tint(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Notification picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Время чек-ин напоминания")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Время отправки вечернего напоминания о том, что нужно сделать отчет детокса.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.green)
                                
                                DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            if !overrideEveningDate.isEmpty {
                                Text("На сегодняшний вечер установлено: \(String(format: "%02d:%02d", overrideEveningHour, overrideEveningMinute))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: { showEveningOverrideSheet = true }) {
                                Text("Изменить только на следующий раз")
                                    .underline()
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            
                        // Morning Notification picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Время утреннего напоминания")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Уведомления будут приходить часто начиная с этого времени, если вы пропустили чек-ин вчера вечером.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.orange)
                                
                                DatePicker("", selection: $morningNotificationTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            if !overrideMorningDate.isEmpty {
                                Text("На завтрашнее утро установлено: \(String(format: "%02d:%02d", overrideMorningHour, overrideMorningMinute))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: { showMorningOverrideSheet = true }) {
                                Text("Изменить только на следующий раз")
                                    .underline()
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Фраза после SOS")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Эта фраза отображается под таймером на главном экране после завершения практики SOS.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            TextField("Введите фразу...", text: $customMantra)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        NavigationLink(destination: SoundSettingsView()) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Настройки звуков")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Тестирование и выбор системных звуков")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
                .padding()
                .padding(.bottom, 60)
            }
            .withAmbientGlow()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let calendar = Calendar.current
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                if let date = calendar.date(from: components) {
                    notificationTime = date
                }
                
                var morningComponents = DateComponents()
                morningComponents.hour = morningNotificationHour
                morningComponents.minute = morningNotificationMinute
                if let date = calendar.date(from: morningComponents) {
                    morningNotificationTime = date
                }
            }
            .onChange(of: notificationTime) { oldValue, newValue in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                notificationHour = components.hour ?? 21
                notificationMinute = components.minute ?? 0
                
                // Reschedule notifications based on latest settings
                let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
            }
            .onChange(of: morningNotificationTime) { oldValue, newValue in
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                morningNotificationHour = components.hour ?? 9
                morningNotificationMinute = components.minute ?? 0
                
                // Reschedule notifications based on latest settings
                let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
            }
            .onChange(of: detoxDayBoundaryHour) { oldValue, newValue in
                // Optionally reschedule if day boundary hour changes
                let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
                WidgetCenter.shared.reloadAllTimelines()
            }
            .sheet(isPresented: $showEveningOverrideSheet) {
                overrideSheet(
                    title: "Изменить вечернее время на 1 раз",
                    description: "Установите временное время для сегодняшнего вечернего чек-ина. После этого вернется обычное время.",
                    tempTime: $tempEveningOverrideTime,
                    saveAction: {
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.hour, .minute], from: tempEveningOverrideTime)
                        
                        let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: lastCheck) {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            overrideEveningDate = formatter.string(from: tomorrow)
                            overrideEveningHour = components.hour ?? 21
                            overrideEveningMinute = components.minute ?? 0
                            
                            NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
                        }
                        showEveningOverrideSheet = false
                    },
                    clearAction: {
                        overrideEveningDate = ""
                        overrideEveningHour = -1
                        overrideEveningMinute = -1
                        let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                        NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
                        showEveningOverrideSheet = false
                    }
                )
            }
            .sheet(isPresented: $showMorningOverrideSheet) {
                overrideSheet(
                    title: "Изменить утреннее время на 1 раз",
                    description: "Установите временное время для завтрашнего утреннего напоминания.",
                    tempTime: $tempMorningOverrideTime,
                    saveAction: {
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.hour, .minute], from: tempMorningOverrideTime)
                        
                        let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                        if let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: lastCheck) {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            overrideMorningDate = formatter.string(from: dayAfterTomorrow)
                            overrideMorningHour = components.hour ?? 9
                            overrideMorningMinute = components.minute ?? 0
                            
                            NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
                        }
                        showMorningOverrideSheet = false
                    },
                    clearAction: {
                        overrideMorningDate = ""
                        overrideMorningHour = -1
                        overrideMorningMinute = -1
                        let lastCheck = progressQuery.first?.lastCheckInDate ?? Date()
                        NotificationManager.shared.scheduleReminders(lastCheckInDate: lastCheck)
                        showMorningOverrideSheet = false
                    }
                )
            }
        }
        .withSOSToolbar()
    }
    
    // Helper to build the override sheet view
    private func overrideSheet(title: String, description: String, tempTime: Binding<Date>, saveAction: @escaping () -> Void, clearAction: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                DatePicker("", selection: tempTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                
                Button(action: saveAction) {
                    Text("Сохранить на один раз")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                
                Button(action: clearAction) {
                    Text("Отменить разовое изменение")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .withAmbientGlow()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        showEveningOverrideSheet = false
                        showMorningOverrideSheet = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct SoundSettingsView: View {
    @State private var soundIDText: String = "1057"
    
    // Maps ID to (Display Name, Filename)
    let commonSounds: [UInt32: (title: String, file: String)] = [
        1000: ("New Mail", "new-mail.caf"),
        1001: ("Mail Sent", "mail-sent.caf"),
        1002: ("Voicemail Received", "Voicemail.caf"),
        1003: ("SMS Received (Ding)", "ReceivedMessage.caf"),
        1004: ("SMS Sent (Swoosh)", "SentMessage.caf"),
        1005: ("Calendar Alert", "sq_alarm.caf"),
        1006: ("Low Power", "low_power.caf"),
        1007: ("SMS Received Alert 1", "sms-received1.caf"),
        1008: ("SMS Received Alert 2", "sms-received2.caf"),
        1009: ("SMS Received Alert 3", "sms-received3.caf"),
        1010: ("SMS Received Alert 4", "sms-received4.caf"),
        1012: ("SMS Received Alert 1", "sms-received1.caf"),
        1013: ("SMS Received Alert 5", "sms-received5.caf"),
        1014: ("SMS Received Alert 6", "sms-received6.caf"),
        1015: ("Voicemail", "Voicemail.caf"),
        1016: ("Tweet Sent", "tweet_sent.caf"),
        1020: ("Anticipate", "Anticipate.caf"),
        1021: ("Bloom", "Bloom.caf"),
        1022: ("Calypso", "Calypso.caf"),
        1023: ("Choo Choo", "Choo_Choo.caf"),
        1024: ("Descent", "Descent.caf"),
        1025: ("Fanfare", "Fanfare.caf"),
        1026: ("Ladder", "Ladder.caf"),
        1027: ("Minuet", "Minuet.caf"),
        1028: ("News Flash", "News_Flash.caf"),
        1029: ("Noir", "Noir.caf"),
        1030: ("Sherwood Forest", "Sherwood_Forest.caf"),
        1031: ("Spell", "Spell.caf"),
        1032: ("Suspense", "Suspense.caf"),
        1033: ("Telegraph", "Telegraph.caf"),
        1034: ("Tiptoes", "Tiptoes.caf"),
        1035: ("Typewriters", "Typewriters.caf"),
        1036: ("Update", "Update.caf"),
        1050: ("USSD Alert", "ussd.caf"),
        1051: ("SIM Toolkit Call Dropped", "SIMToolkitCallDropped.caf"),
        1052: ("SIM Toolkit General Beep", "SIMToolkitGeneralBeep.caf"),
        1053: ("SIM Toolkit Negative ACK", "SIMToolkitNegativeACK.caf"),
        1054: ("SIM Toolkit Positive ACK", "SIMToolkitPositiveACK.caf"),
        1055: ("SIM Toolkit SMS", "SIMToolkitSMS.caf"),
        1057: ("Tink", "Tink.caf"),
        1070: ("Audio Tone Busy", "ct-busy.caf"),
        1071: ("Audio Tone Congestion", "ct-congestion.caf"),
        1072: ("Audio Tone Path Ack", "ct-path-ack.caf"),
        1073: ("Audio Tone Error", "ct-error.caf"),
        1074: ("Audio Tone Call Waiting", "ct-call-waiting.caf"),
        1075: ("Audio Tone Key 2", "ct-keytone2.caf"),
        1100: ("Screen Locked", "sq_lock.caf"),
        1101: ("Screen Unlocked", "sq_lock.caf"),
        1103: ("Key Pressed (Tink)", "sq_tock.caf"),
        1104: ("Key Pressed (Tock)", "sq_tock.caf"),
        1105: ("Key Pressed (Tock)", "sq_tock.caf"),
        1106: ("Connected To Power", "sq_beep-beep.caf"),
        1107: ("Ringer Switch", "RingerChanged.caf"),
        1108: ("Camera Shutter", "photoShutter.caf"),
        1109: ("Shake To Shuffle", "shake.caf"),
        1110: ("JBL Begin", "jbl_begin.caf"),
        1111: ("JBL Confirm", "jbl_confirm.caf"),
        1112: ("JBL Cancel", "jbl_cancel.caf"),
        1113: ("Begin Recording", "begin_record.caf"),
        1114: ("End Recording", "end_record.caf"),
        1115: ("JBL Ambiguous", "jbl_ambiguous.caf"),
        1116: ("JBL No Match", "jbl_no_match.caf"),
        1117: ("Begin Video Recording", "begin_video_record.caf"),
        1118: ("End Video Recording", "end_video_record.caf"),
        1150: ("VC Invitation Accepted", "vc~invitation-accepted.caf"),
        1151: ("VC Ringing", "vc~ringing.caf"),
        1152: ("VC Ended", "vc~ended.caf"),
        1153: ("VC Call Waiting", "ct-call-waiting.caf"),
        1154: ("VC Call Upgrade", "vc~ringing.caf"),
        1200: ("Touch Tone 0", "dtmf-0.caf"),
        1201: ("Touch Tone 1", "dtmf-1.caf"),
        1202: ("Touch Tone 2", "dtmf-2.caf"),
        1203: ("Touch Tone 3", "dtmf-3.caf"),
        1204: ("Touch Tone 4", "dtmf-4.caf"),
        1205: ("Touch Tone 5", "dtmf-5.caf"),
        1206: ("Touch Tone 6", "dtmf-6.caf"),
        1207: ("Touch Tone 7", "dtmf-7.caf"),
        1208: ("Touch Tone 8", "dtmf-8.caf"),
        1209: ("Touch Tone 9", "dtmf-9.caf"),
        1210: ("Touch Tone Star", "dtmf-star.caf"),
        1211: ("Touch Tone Pound", "dtmf-pound.caf"),
        1254: ("Headset Start Call", "long_low_short_high.caf"),
        1255: ("Headset Redial", "short_double_high.caf"),
        1256: ("Headset Answer Call", "short_low_high.caf"),
        1257: ("Headset End Call", "short_double_low.caf"),
        1258: ("Headset Call Waiting Actions", "short_double_low.caf"),
        1259: ("Headset Transition End", "middle_9_short_double_low.caf"),
        1300: ("Preview (Voicemail)", "Voicemail.caf"),
        1301: ("Preview (Received Message)", "ReceivedMessage.caf"),
        1302: ("Preview (New Mail)", "new-mail.caf"),
        1303: ("Preview (Mail Sent)", "mail-sent.caf"),
        1304: ("Preview (Alarm)", "sq_alarm.caf"),
        1305: ("Preview (Lock)", "sq_lock.caf"),
        1306: ("Key Press Click Preview", "sq_tock.caf"),
        1307: ("SMS Selection 1", "sms-received1.caf"),
        1308: ("SMS Selection 2", "sms-received2.caf"),
        1309: ("SMS Selection 3", "sms-received3.caf"),
        1310: ("SMS Selection 4", "sms-received4.caf"),
        1312: ("SMS Selection 1", "sms-received1.caf"),
        1313: ("SMS Selection 5", "sms-received5.caf"),
        1314: ("SMS Selection 6", "sms-received6.caf"),
        1315: ("Preview (Voicemail)", "Voicemail.caf"),
        1320: ("Selection (Anticipate)", "Anticipate.caf"),
        1321: ("Selection (Bloom)", "Bloom.caf"),
        1322: ("Selection (Calypso)", "Calypso.caf"),
        1323: ("Selection (Choo Choo)", "Choo_Choo.caf"),
        1324: ("Selection (Descent)", "Descent.caf"),
        1325: ("Selection (Fanfare)", "Fanfare.caf"),
        1326: ("Selection (Ladder)", "Ladder.caf"),
        1327: ("Selection (Minuet)", "Minuet.caf"),
        1328: ("Selection (News Flash)", "News_Flash.caf"),
        1329: ("Selection (Noir)", "Noir.caf"),
        1330: ("Selection (Sherwood Forest)", "Sherwood_Forest.caf"),
        1331: ("Selection (Spell)", "Spell.caf"),
        1332: ("Selection (Suspense)", "Suspense.caf"),
        1333: ("Selection (Telegraph)", "Telegraph.caf"),
        1334: ("Selection (Tiptoes)", "Tiptoes.caf"),
        1335: ("Selection (Typewriters)", "Typewriters.caf"),
        1336: ("Selection (Update)", "Update.caf")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ТЕСТЕР ЗВУКОВ")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)
                
                HStack {
                    TextField("ID (например 1004)", text: $soundIDText)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        if let id = UInt32(soundIDText) {
                            playSoundWithoutVibration(id: id)
                        }
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Звуки системы (без вибрации):")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                VStack(spacing: 12) {
                    ForEach(commonSounds.keys.sorted(), id: \.self) { id in
                        Button(action: {
                            soundIDText = "\(id)"
                            playSoundWithoutVibration(id: id)
                        }) {
                            HStack {
                                Text("\(id)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                                
                                Spacer()
                                
                                Text(commonSounds[id]?.title ?? "")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
        .withAmbientGlow()
        .navigationTitle("Настройки звуков")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func playSoundWithoutVibration(id: UInt32) {
        if let file = commonSounds[id]?.file {
            let possiblePaths = [
                "/System/Library/Audio/UISounds/\(file)",
                "/System/Library/Audio/UISounds/Modern/\(file)",
                "/System/Library/Audio/UISounds/New/\(file)",
                "/Library/Ringtones/\(file)",
                "/System/Library/Audio/UISounds/nano/\(file)"
            ]
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    if let url = URL(string: "file://\(path)") {
                        var newSoundId: SystemSoundID = 0
                        AudioServicesCreateSystemSoundID(url as CFURL, &newSoundId)
                        AudioServicesPlaySystemSound(newSoundId)
                        return
                    }
                }
            }
        }
        
        // Fallback if we don't have the file name mapped or it wasn't found
        AudioServicesPlaySystemSound(SystemSoundID(id))
    }
}

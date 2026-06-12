/**
 * 通知テンプレート定義
 *
 * 文言を変更したい場合はこのファイルだけ編集すればOK。
 * プレースホルダー:
 *   {fromName} — 送信者の表示名
 */

interface NotificationTemplate {
  /** 通知タイトル */
  title: string;
  /** 通知本文（{fromName} が送信者名に置換される） */
  body: string;
  /**
   * 通知音のファイル名（アプリバンドル内の caf）。
   * 送信時のアプリ内効果音（FeedbackService の hey_default 等）と揃える。
   */
  sound: string;
}

/** messageType → 通知テンプレートのマッピング */
export const NOTIFICATION_TEMPLATES: Record<string, NotificationTemplate> = {
  hey: {
    title: "Hey",
    body: "{fromName}からHeyが届きました",
    sound: "hey_default.caf",
  },
  ho: {
    title: "Ho",
    body: "{fromName}からHoが届きました",
    sound: "ho_default.caf",
  },
  letsGo: {
    title: "Let's Go",
    body: "{fromName}からLet's Goが届きました",
    sound: "letsgo_default.caf",
  },
};

/** デフォルトテンプレート（未知の messageType 用） */
const DEFAULT_TEMPLATE: NotificationTemplate = {
  title: "HeyHo",
  body: "{fromName}からメッセージが届きました",
  sound: "default",
};

/**
 * messageType と送信者名から通知の title / body を生成する
 */
export function buildNotification(
  messageType: string,
  fromName: string
): { title: string; body: string } {
  const template = NOTIFICATION_TEMPLATES[messageType] ?? DEFAULT_TEMPLATE;
  return {
    title: template.title,
    body: template.body.replace("{fromName}", fromName),
  };
}

/**
 * messageType に対応する通知音のファイル名を返す（APNS の aps.sound 用）。
 * 未知の messageType は iOS 標準音（"default"）。
 */
export function notificationSound(messageType: string): string {
  return (NOTIFICATION_TEMPLATES[messageType] ?? DEFAULT_TEMPLATE).sound;
}

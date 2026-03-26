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
}

/** messageType → 通知テンプレートのマッピング */
export const NOTIFICATION_TEMPLATES: Record<string, NotificationTemplate> = {
  hey: {
    title: "Hey",
    body: "{fromName}からHeyが届きました",
  },
  ho: {
    title: "Ho",
    body: "{fromName}からHoが届きました",
  },
  letsGo: {
    title: "Let's Go",
    body: "{fromName}からLet's Goが届きました",
  },
};

/** デフォルトテンプレート（未知の messageType 用） */
const DEFAULT_TEMPLATE: NotificationTemplate = {
  title: "HeyHo",
  body: "{fromName}からメッセージが届きました",
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

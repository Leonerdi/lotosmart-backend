import type {
  AuthOkData,
  CombatLogsPayload,
  MirrorIntent,
  ServerViewModel,
  WsOutgoingMessage
} from "../types/protocol";
import { parseWsIncomingMessage } from "../types/wsSchemas";

type SnapshotListener = (state: ServerViewModel) => void;
type AuthListener = (auth: AuthOkData) => void;
type CombatLogsListener = (payload: CombatLogsPayload) => void;

export class MirrorSocketClient {
  private readonly ws: WebSocket;

  constructor(
    endpoint: string,
    private readonly onSnapshot: SnapshotListener,
    private readonly onAuthOk?: AuthListener,
    private readonly onCombatLogs?: CombatLogsListener,
    private readonly sessionTicket?: string
  ) {
    this.ws = new WebSocket(endpoint);
    this.ws.addEventListener("open", this.handleOpen);
    this.ws.addEventListener("message", this.handleMessage);
  }

  private handleOpen = (): void => {
    if (!this.sessionTicket) {
      return;
    }

    const authMessage: WsOutgoingMessage = {
      type: "AUTH",
      data: { sessionTicket: this.sessionTicket }
    };

    this.ws.send(JSON.stringify(authMessage));
  };

  private handleMessage = (event: MessageEvent<string>): void => {
    const parsed = parseWsIncomingMessage(event.data);
    if (!parsed.success) {
      console.error("[ws] mensagem invalida", parsed.error);
      return;
    }

    const payload = parsed.data;

    if (payload.type === "SNAPSHOT") {
      this.onSnapshot(payload.data);
      return;
    }

    if (payload.type === "AUTH_OK") {
      this.onAuthOk?.(payload.data);
      return;
    }

    if (payload.type === "COMBAT_LOGS") {
      this.onCombatLogs?.(payload.data);
    }
  };

  sendIntent(intent: MirrorIntent): void {
    if (this.ws.readyState !== WebSocket.OPEN) {
      return;
    }

    this.ws.send(JSON.stringify({ type: "INTENT", data: intent }));
  }

  dispose(): void {
    this.ws.removeEventListener("open", this.handleOpen);
    this.ws.removeEventListener("message", this.handleMessage);
    this.ws.close();
  }
}

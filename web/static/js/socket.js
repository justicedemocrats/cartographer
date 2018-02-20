import { Socket } from "phoenix";
let socket = new Socket("/", { params: { token: window.userToken } });
socket.connect();
export default socket;

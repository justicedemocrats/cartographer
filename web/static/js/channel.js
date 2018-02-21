// import socket from "./socket";

// const channel = socket.channel("map");

// const initialize = () =>
//   new Promise((resolve, reject) =>
//     channel
//       .join()
//       .receive("ok", resp => resolve(channel))
//       .on("error", reject)
//   );

// const getEvents = () => channel.push("events");
// const getEventsFor = candidate => channel.push("events", { candidate });

// export default { initialize, getEvents, getEventsFor };

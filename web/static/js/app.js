import React, { Component } from "react";
import { render } from "react-dom";
import ReactMapGL from "react-map-gl";
import socket from "./socket";

class Map extends Component {
  state = {
    width: 400,
    height: 400,
    viewport: {
      latitude: 37.7577,
      longitude: -122.4376,
      zoom: 8
    },
    channel: null,
    events: [],
    mapboxApiAccessToken: undefined
  };

  componentWillMount() {
    this.state.mapboxApiAccessToken = document
      .getElementById("mapbox_api_access_token")
      .getAttribute("data");

    this.state.width = window.inerWidth;
    this.state.height = window.innerHeight;
    console.log(this.state);
  }

  componentDidMount() {
    this.channel = socket.channel("map");
    this.channel
      .join()
      .receive("ok", resp => {
        this.channel.push("events");
        // channel.push("events", { candidate });
      })
      .receive("error", console.error);

    this.channel.on("event", event => {
      this.state.events.push(event);
      this.forceUpdate();
    });
  }

  refreshEvents = () =>
    this.setState({ events: [] }, () => channel.push("events"));

  render() {
    return (
      <ReactMapGL
        {...this.state.viewport}
        width={this.state.width}
        height={this.state.height}
        onViewPortChange={viewport => this.setState({ viewport })}
        mapboxApiAccessToken={this.state.mapboxApiAccessToken}
      />
    );
  }
}

render(<Map />, document.querySelector("#app"));

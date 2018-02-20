import React, { Component } from "react";
import { render } from "react-dom";
import ReactMapGL from "react-map-gl";
import data from "./channel";

class Map extends Component {
  state = {
    viewport: {
      width: 400,
      height: 400,
      latitude: 37.7577,
      longitude: -122.4376,
      zoom: 8
    },
    channel: null,
    events: {}
  };

  componentDidMount() {
    data.initalize().then(ch => {
      this.state.channel = ch;
      data.getEvents();

      this.state.channel.on("event", event => {
        this.state.events[event.id] = event;
        this.forceUpdate();
      });
    });
  }

  render() {
    return (
      <ReactMapGL
        {...this.state.viewport}
        onViewPortChange={viewport => this.setState({ viewport })}
      />
    );
  }
}

render(<Map />, document.querySelector("#app"));

import React, { Component } from "react";
import { render } from "react-dom";
import ReactMapGL from "react-map-gl";
import socket from "./socket";

class Map extends Component {
  state = {
    viewport: {
      width: 400,
      height: 400,
      latitude: 37.7577,
      longitude: -122.4376,
      zoom: 8
    }
  };

  componentDidMount () {
    console.log('hi')
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

import React, { Component } from "react";
import { render } from "react-dom";
import ReactMapGL from "react-map-gl";

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
    events: {},
    mapboxApiAccessToken: undefined
  };

  componentWillMount() {
    this.state.mapboxApiAccessToken = document
      .getElementById("mapbox_api_access_token")
      .getAttribute("data");
  }

  render() {
    console.log(this.state.mapboxApiAccessToken);

    return (
      <ReactMapGL
        {...this.state.viewport}
        onViewPortChange={viewport => this.setState({ viewport })}
        mapboxApiAccessToken={this.state.mapboxApiAccessToken}
      />
    );
  }
}

render(<Map />, document.querySelector("#app"));

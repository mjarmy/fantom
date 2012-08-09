//
// Copyright (c) 2011, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jun 09  Andy Frank  Creation
//

fan.webfwt.GMapPeer = fan.sys.Obj.$extend(fan.fwt.PanePeer);

fan.webfwt.GMapPeer.prototype.$ctor = function(self)
{
  fan.fwt.PanePeer.prototype.$ctor.call(this, self);
  this.markers = [];
  this.routes  = [];
}

fan.webfwt.GMapPeer.prototype.create = function(parentElem, self)
{
  this.map = null;
  return fan.fwt.WidgetPeer.prototype.create.call(this, parentElem, self);
}

fan.webfwt.GMapPeer.prototype.addMarker = function(self, lat, lng, info)
{
  if (info === undefined) info = null;
  lat = lat.valueOf();
  lng = lng.valueOf();
  this.updateBounds(lat, lng);
  this.markers.push({lat:lat, lng:lng, info:info});
}

fan.webfwt.GMapPeer.prototype.addRoute = function(self, route, col)
{
  if (col != undefined) col = col.toCss();

  if (route.size() % 2 != 0)
    throw fan.sys.ArgErr.make("Invalid route length");

  var path = [];
  for (var i=0; i<route.size(); i+=2)
  {
    var lat = route.get(i).valueOf();
    var lng = route.get(i+1).valueOf();
    this.updateBounds(lat, lng);
    path.push({lat:lat, lng:lng});
  }

  this.routes.push({
    path: path,
    strokeColor: col,
    strokeOpacity: 0.5,
    strokeWeight: 2
  });
}

fan.webfwt.GMapPeer.prototype.updateBounds = function(lat, lng)
{
  this.minLat = this.minLat==null ? lat : Math.min(this.minLat, lat);
  this.minLng = this.minLng==null ? lng : Math.min(this.minLng, lng);
  this.maxLat = this.maxLat==null ? lat : Math.max(this.maxLat, lat);
  this.maxLng = this.maxLng==null ? lng : Math.max(this.maxLng, lng);
}

fan.webfwt.GMapPeer.prototype.sync = function(self)
{
  fan.fwt.WidgetPeer.prototype.sync.call(this, self);

  // short-circut if scripts not loaded yet
  if (!fan.webfwt.GMapPeer.scriptLoaded)
  {
    this.loadScript(self);
    return;
  }

  try
  {
    if (this.map == null && this.m_size.m_w > 0)
    {
      // TODO FIXIT - this code works with the V3 API
      //  - Would be nice to fitBounds *before* creating map

      // defaults to centered on US
      var bounds = null;
      var options =
      {
        center: new google.maps.LatLng(39.978030, -95.295274),
        zoom: self.m_zoom,
        mapTypeId: this.getMapType(self)
      };

      // center on bounding box of all markers
      if (this.markers.length > 0 || this.routes.length > 0)
      {
        // center on bounding box of all markers
        bounds = new google.maps.LatLngBounds(
          new google.maps.LatLng(this.minLat, this.minLng),
          new google.maps.LatLng(this.maxLat, this.maxLng));
        options.center = bounds.getCenter();
      }

      // create map
      this.map = new google.maps.Map(this.elem, options);

      // create info window
      this.infoWindow = new google.maps.InfoWindow({ content: "InfoWindow" });

      // assign markers
      for (var i=0; i<this.markers.length; i++)
      {
        var m = this.markers[i];
        var g = new google.maps.Marker({
          position: new google.maps.LatLng(m.lat, m.lng),
          map: this.map
        });
        if (m.info != null)
          google.maps.event.addListener(g, 'click', this.onMarkerClick(g, m.info));
      }

      // add routes
      for (var i=0; i<this.routes.length; i++)
      {
        var r = this.routes[i];
        var path = [];

        for (var j=0; j<r.path.length; j++)
        {
          var p = r.path[j];
          path.push(new google.maps.LatLng(p.lat, p.lng));
        }

        new google.maps.Polyline({
          path: path,
          strokeColor: r.strokeColor,
          strokeOpacity: r.strokeOpacity,
          strokeWeight: r.strokeWidth,
          map: this.map
        });
      }

      // fit bounds
      if (bounds != null)
      {
        // we must trap the zoom after our fitBounds call
        // async to accurately limit our zoom level
        google.maps.event.addListener(this.map, 'bounds_changed', function(event)
        {
          if (this.getZoom() > 15 && this.initialZoom == true)
          {
            this.setZoom(15);
            this.initialZoom = false;
          }
        });
        this.map.initialZoom = true;
        this.map.fitBounds(bounds);
      }
    }
  }
  catch (err)
  {
    fan.sys.ObjUtil.echo(err);
    this.elem.innerHTML = "Could not load map";
    this.elem.style.padding = "12px";
    fan.fwt.WidgetPeer.prototype.sync.call(this, self);
    return;
  }
}

fan.webfwt.GMapPeer.prototype.onMarkerClick = function(marker, info)
{
  var t = this;
  return function() {
    t.infoWindow.content = info;
    t.infoWindow.open(t.map, marker);
  }
}

fan.webfwt.GMapPeer.prototype.getMapType = function(self)
{
  var v = self.m_mapType;
  if (v == fan.webfwt.MapType.m_roadMap)   return google.maps.MapTypeId.ROADMAP;
  if (v == fan.webfwt.MapType.m_satellite) return google.maps.MapTypeId.SATELLITE;
  if (v == fan.webfwt.MapType.m_hybrid)    return google.maps.MapTypeId.HYBRID;
  if (v == fan.webfwt.MapType.m_terrain)   return google.maps.MapTypeId.TERRAIN;
  return google.maps.MapTypeId.ROADMAP;
}

fan.webfwt.GMapPeer.prototype.loadScript = function(self)
{
  if (fan.webfwt.GMapPeer.scriptLoading) return;
  fan.webfwt.GMapPeer.scriptLoading = true;

  fanFrescoGMapPeerOnLoad = function()
  {
    fan.webfwt.GMapPeer.scriptLoaded = true;
    var win = self.window();
    if (win != null) win.relayout();
  }

  var script = document.createElement("script");
  script.type = "text/javascript";
  script.src = "http://maps.google.com/maps/api/js?sensor=false&callback=fanFrescoGMapPeerOnLoad";
  document.body.appendChild(script);
}

var fanFrescoGMapPeerOnLoad = null;
fan.webfwt.GMapPeer.scriptLoading = false;
fan.webfwt.GMapPeer.scriptLoaded = false;

fan.webfwt.GMapPeer.prototype.markers = null;  // set in ctor
fan.webfwt.GMapPeer.prototype.routes  = null;  // set in ctor

fan.webfwt.GMapPeer.prototype.minLat = null;   // set in updateBounds
fan.webfwt.GMapPeer.prototype.minLng = null;
fan.webfwt.GMapPeer.prototype.maxLat = null;
fan.webfwt.GMapPeer.prototype.maxLng = null;

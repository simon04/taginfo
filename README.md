Taginfo
=======

Brings together information about OpenStreetMap tags and makes it searchable and browsable.

Documentation: <http://wiki.openstreetmap.org/wiki/Taginfo>  
Live System: <http://taginfo.openstreetmap.de/>


Files
-----

* `sources`  – import scripts
* `web`      – Web User Interface and API
* `examples` – script to use the API
* `tagstats` – C++ program to create database statistics


Prerequisites
-------------

Uses:

* Mongrel
* Sinatra web framework <http://www.sinatrarb.com/>
* Rack Contrib Gem (for Rack::JSONP)
* JSON gem (install with gem, Debian/Ubuntu packages are too old and buggy)
* jQuery (www.jquery.com), necessary files are included
* Flexigrid (Originally from <http://code.google.com/p/flexigrid/>
  <http://www.flexigrid.info/> , the version used and included
  is the one from <http://github.com/joto/flexigrid> with
  some bugfixes.)

Icon from:  
    <http://www.openclipart.org/detail/20131>

Debian/Ubuntu packages:  
```
rubygems
```

Gems:  
```
gem install mongrel rack rack-contrib sinatra json
```

There is a developer mailing list at
<http://lists.openstreetmap.org/listinfo/taginfo-dev>


Data Import
-----------

See <http://wiki.openstreetmap.org/wiki/Taginfo/Running>


Web User Interface
------------------

You need a `data` directory in the parent directory of the directory where
this README is. It must contain the sqlite database files created in the
data import step or downloaded from <http://taginfo.openstreetmap.de/download>.

To start the web user interface:  
```
cd web
./taginfo.rb
```


Thanks
------
Stefano Tampieri – for the Italian translation


Author
------

Jochen Topf <jochen@remote.org>  
<http://wiki.openstreetmap.org/wiki/User:Joto>


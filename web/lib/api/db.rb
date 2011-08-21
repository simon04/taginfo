# web/lib/api/db.rb
class Taginfo < Sinatra::Base

    @@filters = {
        :characters_space       => { :expr => "characters='space'",   :doc => 'Only show keys with spaces.' },
        :characters_problematic => { :expr => "characters='problem'", :doc => 'Only show keys with problematic characters.' },
        :in_wiki                => { :expr => "in_wiki=1",            :doc => 'Only show keys that appear in the wiki.' },
        :not_in_db              => { :expr => "count_all=0",          :doc => 'Only show keys that do not appear in the database.' }
    }

    api(2, 'db/keys', {
        :description => 'Get list of keys that are in the database or mentioned in any other source.',
        :parameters => { :query => 'Only show keys matching this query (substring match, optional).' },
        :paging => :optional,
        :filter => @@filters,
        :sort => %w( key count_all count_nodes count_ways count_closedways count_relations values_all users_all in_wiki in_josm in_potlatch length ),
        :result => {
            :key                      => :STRING, 
            :count_all                => :INT,
            :count_all_fraction       => :FLOAT,
            :count_nodes              => :INT,
            :count_nodes_fraction     => :FLOAT,
            :count_ways               => :INT,
            :count_ways_fraction      => :FLOAT,
            :count_closedways         => :INT,
            :count_closedways_fraction=> :FLOAT,
            :count_relations          => :INT,
            :count_relations_fraction => :FLOAT,
            :values_all               => :INT,
            :users_all                => :INT,
            :in_wiki                  => :BOOL,
            :in_josm                  => :BOOL,
            :in_potlatch              => :BOOL
        },
        :example => { :page => 1, :rp => 10, :filter => 'in_wiki', :sortname => 'key', :sortorder => 'asc' },
        :ui => '/keys'
    }) do

        if params[:filters]
            filters = params[:filters].split(',').map{ |f| @@filters[f.to_sym][:expr] }.compact
        else
            filters = []
        end

        include_data = Hash.new
        if params[:include]
            params[:include].split(',').each{ |inc| include_data[inc.to_sym] = 1 }
        end

        total = @db.count('db.keys').
            condition_if("key LIKE '%' || ? || '%'", params[:query]).
            conditions(filters).
            get_first_value().to_i
        
        res = @db.select('SELECT * FROM db.keys').
            condition_if("key LIKE '%' || ? || '%'", params[:query]).
            conditions(filters).
            order_by(params[:sortname], params[:sortorder]) { |o|
                o.key
                o.count_all
                o.count_nodes
                o.count_ways
                o.count_closedways
                o.count_relations
                o.values_all
                o.users_all
                o.in_wiki
                o.in_josm
                o.in_potlatch
                o.length 'length(key)'
                o.length :key
            }.
            paging(params[:rp], params[:page]).
            execute()

        if include_data[:wikipages]
            reshash = Hash.new
            res.each do |row|
                reshash[row['key']] = row
                row['wikipages'] = Array.new
            end

            wikipages = @db.select('SELECT key, lang, title, type FROM wiki.wikipages').
                condition("value IS NULL").
                condition("key IN (#{ res.map{ |row| "'" + SQLite3::Database.quote(row['key']) + "'" }.join(',') })").
                order_by([:key, :lang]).
                execute()

            wikipages.each do |wp|
                key = wp['key']
                wp.delete_if{ |k,v| k.is_a?(Integer) || k == 'key' }
                reshash[key]['wikipages'] << wp
            end
        end

        if include_data[:prevalent_values]
            reshash = Hash.new
            res.each do |row|
                reshash[row['key']] = row
                row['prevalent_values'] = Array.new
            end

            prevvalues = @db.select('SELECT key, value, count, fraction FROM db.prevalent_values').
                condition("key IN (#{ res.map{ |row| "'" + SQLite3::Database.quote(row['key']) + "'" }.join(',') })").
                order_by([:count], 'DESC').
                execute()

            prevvalues.each do |pv|
                key = pv['key']
                pv.delete_if{ |k,v| k.is_a?(Integer) || k == 'key' }
                pv['count'] = pv['count'].to_i
                pv['fraction'] = pv['fraction'].to_f
                reshash[key]['prevalent_values'] << pv
            end
        end

        return {
            :page  => params[:page].to_i,
            :rp    => params[:rp].to_i,
            :total => total,
            :data  => res.map{ |row| h = {
                :key                      => row['key'],
                :count_all                => row['count_all'].to_i,
                :count_all_fraction       => row['count_all'].to_f / @db.stats('objects'),
                :count_nodes              => row['count_nodes'].to_i,
                :count_nodes_fraction     => row['count_nodes'].to_f / @db.stats('nodes_with_tags'),
                :count_ways               => row['count_ways'].to_i,
                :count_ways_fraction      => row['count_ways'].to_f / @db.stats('ways'),
                :count_closedways         => row['count_closedways'].to_i,
                :count_closedways_fraction=> row['count_closedways'].to_f / @db.stats('closed_ways'),
                :count_relations          => row['count_relations'].to_i,
                :count_relations_fraction => row['count_relations'].to_f / @db.stats('relations'),
                :values_all               => row['values_all'].to_i,
                :users_all                => row['users_all'].to_i,
                :in_wiki                  => row['in_wiki']     == '1' ? true : false,
                :in_josm                  => row['in_josm']     == '1' ? true : false,
                :in_potlatch              => row['in_potlatch'] == '1' ? true : false,
            } 
            h[:wikipages] = row['wikipages'] if row['wikipages']
            h[:prevalent_values] = row['prevalent_values'][0,10] if row['prevalent_values']
            h }
        }.to_json
    end

    api(2, 'db/keys/overview', {
        :description => 'Show statistics for nodes, ways, closed ways, relations and total for this key.',
        :parameters => { :key => 'Tag key (required).' },
        :paging => :no,
        :result => {
            :nodes => {
                :count => :INT,
                :count_fraction => :FLOAT,
                :values => :INT
            },
            :ways => {
                :count => :INT,
                :count_fraction => :FLOAT,
                :values => :INT
            },
            :closedways => {
                :count => :INT,
                :count_fraction => :FLOAT,
                :values => :INT
            },
            :relations => {
                :count => :INT,
                :count_fraction => :FLOAT,
                :values => :INT
            },
            :all => {
                :count => :INT,
                :count_fraction => :FLOAT,
                :values => :INT
            },
            :users => :INT
        },
        :example => { :key => 'highway' },
        :ui => '/keys/highway'
    }) do
        key = params[:key]
        out = Hash.new

        # default values
        ['all', 'nodes', 'ways', 'closedways', 'relations'].each do |type|
            out[type] = { :count => 0, :count_fraction => 0.0, :values => 0 }
        end
        out['users'] = 0;

        @db.select('SELECT * FROM db.keys').
            condition('key = ?', key).
            execute() do |row|
                ['all', 'nodes', 'ways', 'closedways', 'relations'].each do |type|
                    out[type] = {
                        :count          => row['count_'  + type].to_i,
                        :count_fraction => row['count_'  + type].to_f / get_total(type),
                        :values         => row['values_' + type].to_i
                    }
                end
                out['users'] = row['users_all'].to_i
        end

        out.to_json
    end

    api(2, 'db/keys/distribution', {
        :description => 'Get map with distribution of this key in the database.',
        :parameters => { :key => 'Tag key (required).' },
        :result => 'PNG image.',
        :example => { :key => 'amenity' },
        :ui => '/keys/highway#map'
    }) do
        key = params[:key]
        content_type :png
        @db.select('SELECT png FROM db.key_distributions').
            condition('key = ?', key).
            get_first_value()
    end

    api(2, 'db/keys/values', {
        :description => 'Get values used with a given key.',
        :parameters => {
            :key => 'Tag key (required).',
            :query => 'Only show results where the value matches this query (substring match, optional).'
        },
        :paging => :optional,
        :filter => {
            :all        => { :doc => 'No filter.' },
            :nodes      => { :doc => 'Only values on tags used on nodes.' },
            :ways       => { :doc => 'Only values on tags used on ways.' },
            :closedways => { :doc => 'Only values on tags used on closed ways.' },
            :relations  => { :doc => 'Only values on tags used on relations.' }
        },
        :sort => %w( value count_all count_nodes count_ways count_closedways count_relations ),
        :result => { :value => :STRING, :count => :INT, :fraction => :FLOAT },
        :example => { :key => 'highway', :page => 1, :rp => 10, :sortname => 'count_ways', :sortorder => 'desc' },
        :ui => '/keys/highway#values'
    }) do
        key = params[:key]
        filter_type = get_filter()

        if params[:sortname] == 'count'
            params[:sortname] = 'count_' + filter_type
        end

        (this_key_count, total) = @db.select("SELECT count_#{filter_type} AS count, values_#{filter_type} AS count_values FROM db.keys").
            condition('key = ?', key).
            get_columns(:count, :count_values)

        if params[:query].to_s != ''
            total = @db.count('db.tags').
                condition("count_#{filter_type} > 0").
                condition('key = ?', key).
                condition_if("value LIKE '%' || ? || '%'", params[:query]).
                get_first_value()
        end

        res = @db.select('SELECT * FROM db.tags').
            condition("count_#{filter_type} > 0").
            condition('key = ?', key).
            condition_if("value LIKE '%' || ? || '%'", params[:query]).
            order_by(params[:sortname], params[:sortorder]){ |o|
                o.value
                o.count_all
                o.count_nodes
                o.count_ways
                o.count_closedways
                o.count_relations
            }.
            paging(params[:rp], params[:page]).
            execute()

        return {
            :page  => params[:page].to_i,
            :rp    => params[:rp].to_i,
            :total => total.to_i,
            :data  => res.map{ |row| {
                :value    => row['value'],
                :count    => row['count_' + filter_type].to_i,
                :fraction => row['count_' + filter_type].to_f / this_key_count.to_f
            } }
        }.to_json
    end

    api(2, 'db/keys/keys', {
        :description => 'Find keys that are used together with a given key.',
        :parameters => { :key => 'Tag key (required).' },
        :paging => :optional,
        :filter => {
            :all       => { :doc => 'No filter.' },
            :nodes     => { :doc => 'Only values on tags used on nodes.' },
            :ways      => { :doc => 'Only values on tags used on ways.' },
            :closedways=> { :doc => 'Only values on tags used on closed ways.' },
            :relations => { :doc => 'Only values on tags used on relations.' }
        },
        :sort => %w( together_count other_key from_fraction ),
        :result => {
            :other_key      => :STRING,
            :together_count => :INT,
            :to_fraction    => :FLOAT,
            :from_fraction  => :FLOAT
        },
        :example => { :key => 'highway', :page => 1, :rp => 10, :sortname => 'together_count', :sortorder => 'desc' },
        :ui => '/keys/highway#keys'
    }) do
        key = params[:key]
        filter_type = get_filter()

        if params[:sortname] == 'to_count'
            params[:sortname] = 'together_count'
        elsif params[:sortname] == 'from_count'
            params[:sortname] = ['from_fraction', 'together_count', 'other_key']
        end

        total = @db.count('db.keypairs').
            condition('key1 = ? OR key2 = ?', key, key).
            condition("count_#{filter_type} > 0").
            get_first_value().to_i

        has_this_key = @db.select("SELECT count_#{filter_type} FROM db.keys").
            condition('key = ?', key).
            get_first_value()

        res = @db.select("SELECT p.key1 AS other_key, p.count_#{filter_type} AS together_count, k.count_#{filter_type} AS other_count, CAST(p.count_#{filter_type} AS REAL) / k.count_#{filter_type} AS from_fraction FROM db.keypairs p, db.keys k WHERE p.key1=k.key AND p.key2=? AND p.count_#{filter_type} > 0 
                    UNION SELECT p.key2 AS other_key, p.count_#{filter_type} AS together_count, k.count_#{filter_type} AS other_count, CAST(p.count_#{filter_type} AS REAL) / k.count_#{filter_type} AS from_fraction FROM db.keypairs p, db.keys k WHERE p.key2=k.key AND p.key1=? AND p.count_#{filter_type} > 0", key, key).
            order_by(params[:sortname], params[:sortorder]){ |o|
                o.together_count
                o.other_key
                o.from_fraction
            }.
            paging(params[:rp], params[:page]).
            execute()

        return {
            :page  => params[:page].to_i,
            :rp    => params[:rp].to_i,
            :total => total,
            :data  => res.map{ |row| {
                :other_key      => row['other_key'],
                :together_count => row['together_count'].to_i,
                :to_fraction    => row['together_count'].to_f / has_this_key.to_f,
                :from_fraction  => row['from_fraction'].to_f
            } }
        }.to_json
    end

    api(2, 'db/popular_keys') do
        total = @db.count('popular_keys').
            condition_if("key LIKE '%' || ? || '%'", params[:query]).
            get_first_value().to_i
        
        res = @db.select('SELECT * FROM popular_keys').
            condition_if("key LIKE '%' || ? || '%'", params[:query]).
            order_by(params[:sortname], params[:sortorder]){ |o|
                o.key
                o.scale_count
                o.scale_user
                o.scale_wiki
                o.scale_josm
                o.scale1
                o.scale2
            }.
            paging(params[:rp], params[:page]).
            execute()

        return {
            :page  => params[:page].to_i,
            :rp    => params[:rp].to_i,
            :total => total,
            :data  => res.map{ |row| {
                :key         => row['key'],
                :scale_count => row['scale_count'].to_f,
                :scale_users => row['scale_users'].to_f,
                :scale_wiki  => row['scale_wiki'].to_f,
                :scale_josm  => row['scale_josm'].to_f,
                :scale1      => row['scale1'].to_f,
                :scale2      => row['scale2'].to_f
            } }
        }.to_json
    end

    api(2, 'db/tags/overview', {
        :description => 'Show statistics for nodes, ways, closed ways, relations and total for this tag.',
        :parameters => {
            :key => 'Tag key (required).',
            :value => 'Tag value (required).'
        },
        :paging => :no,
        :result => {
            :nodes => {
                :count => :INT,
                :count_fraction => :FLOAT,
            },
            :ways => {
                :count => :INT,
                :count_fraction => :FLOAT,
            },
            :closedways => {
                :count => :INT,
                :count_fraction => :FLOAT,
            },
            :relations => {
                :count => :INT,
                :count_fraction => :FLOAT,
            },
            :all => {
                :count => :INT,
                :count_fraction => :FLOAT,
            }
        },
        :example => { :key => 'highway', :value => 'residential' },
        :ui => '/tags/highway=residential'
    }) do
        key   = params[:key]
        value = params[:value]

        out = Hash.new

        # default values
        ['all', 'nodes', 'ways', 'closedways', 'relations'].each do |type|
            out[type] = { :count => 0, :count_fraction => 0.0 }
        end

        @db.select('SELECT * FROM db.tags').
            condition('key = ?', key).
            condition('value = ?', value).
            execute() do |row|
                ['all', 'nodes', 'ways', 'closedways', 'relations'].each do |type|
                    out[type] = {
                        :count          => row['count_'  + type].to_i,
                        :count_fraction => row['count_'  + type].to_f / get_total(type)
                    }
                end
        end

        out.to_json
    end

end

module StandardFile
  class SyncManager

    attr_accessor :sync_fields

    def initialize(user)
      @user = user
      raise "User must be set" unless @user
    end

    def set_sync_fields(val)
      @sync_fields = val
    end

    def sync_fields
      return @sync_fields || [:content, :enc_item_key, :content_type, :auth_hash, :deleted, :created_at]
    end

    def sync(item_hashes, options)

      in_sync_token = options[:sync_token]
      in_cursor_token = options[:cursor_token]
      limit = options[:limit]

      retrieved_items, cursor_token = _sync_get(in_sync_token, in_cursor_token, limit).to_a
      last_updated = DateTime.now
      saved_items, unsaved_items = _sync_save(item_hashes)
      if saved_items.length > 0
        last_updated = saved_items.sort_by{|m| m.updated_at}.last.updated_at
      end

      check_for_conflicts(saved_items, retrieved_items, unsaved_items)

      # add 1 microsecond to avoid returning same object in subsequent sync
      last_updated = (last_updated.to_time + 1/100000.0).to_datetime.utc

      sync_token = sync_token_from_datetime(last_updated)
      return {
        :retrieved_items => retrieved_items,
        :saved_items => saved_items,
        :unsaved => unsaved_items,
        :sync_token => sync_token,
        :cursor_token => cursor_token
      }
    end

    def check_for_conflicts(saved_items, retrieved_items, unsaved_items)
      # conflicts occur when you are trying to save an item for which there is a pending change already
      min_conflict_interval = 20

      saved_ids = saved_items.map{|x| x.uuid }
      retrieved_ids = retrieved_items.map{|x| x.uuid }
      conflicts = saved_ids & retrieved_ids # & is the intersection
      # saved items take precedence, retrieved items are duplicated with a new uuid
      conflicts.each do |conflicted_uuid|
        # if changes are greater than min_conflict_interval seconds apart,
        # push the retrieved item in the unsaved array so that the client can duplicate it
        saved = saved_items.find{|i| i.uuid == conflicted_uuid}
        conflicted = retrieved_items.find{|i| i.uuid == conflicted_uuid}
        if (saved.updated_at - conflicted.updated_at).abs > min_conflict_interval
          # puts "\n\n\n Creating conflicted copy of #{saved.uuid}\n\n\n"

          unsaved_items.push({
            :item => conflicted,
            :error => {:tag => "sync_conflict"}
          })

          retrieved_items.delete(conflicted)
        end
      end
    end

    def destroy_items(uuids)
      items = @user.items.where(uuid: uuids)
      items.destroy_all
    end


    private

    def sync_token_from_datetime(datetime)
      version = 2
      Base64.encode64("#{version}:" + "#{datetime.to_f}")
    end

    def datetime_from_sync_token(sync_token)
      decoded = Base64.decode64(sync_token)
      parts = decoded.rpartition(":")
      timestamp_string = parts.last
      version = parts.first
      if version == "1"
        date = DateTime.strptime(timestamp_string,'%s')
      elsif version == "2"
        date = Time.at(timestamp_string.to_f).to_datetime.utc
      end

      return date
    end

    def _sync_save(item_hashes)
      if !item_hashes
        return [], []
      end
      saved_items = []
      unsaved = []

      item_hashes.each do |item_hash|
        begin
          item = @user.items.find_or_create_by(:uuid => item_hash[:uuid])
        rescue => error
          unsaved.push({
            :item => item_hash,
            :error => {:message => error.message, :tag => "uuid_conflict"}
            })
          next
        end

        item.update(item_hash.permit(*permitted_params))
        # we want to force update the updated_at field, even if no changes were made
        # item.touch

        if item.deleted == true
          set_deleted(item)
          item.save
        end

        saved_items.push(item)
      end

      return saved_items, unsaved
    end

    def _sync_get(sync_token, input_cursor_token, limit)
      cursor_token = nil
      if limit == nil
        limit = 100000
      end

      # if both are present, cursor_token takes precendence as that would eventually return all results
      # the distinction between getting results for a cursor and a sync token is that cursor results use a
      # >= comparison, while a sync token uses a > comparison. The reason for this is that cursor tokens are
      # typically used for initial syncs or imports, where a bunch of notes could have the exact same updated_at
      # by using >=, we don't miss those results on a subsequent call with a cursor token
      if input_cursor_token
        date = datetime_from_sync_token(input_cursor_token)
        items = @user.items.order(:updated_at).where("updated_at >= ?", date)
      elsif sync_token
        date = datetime_from_sync_token(sync_token)
        items = @user.items.order(:updated_at).where("updated_at > ?", date)
      else
        items = @user.items.order(:updated_at)
      end

      items = items.sort_by{|m| m.updated_at}

      if items.count > limit
        items = items.slice(0, limit)
        date = items.last.updated_at
        cursor_token = sync_token_from_datetime(date)
      end

      return items, cursor_token
    end

    def set_deleted(item)
      item.deleted = true
      item.content = nil if item.has_attribute?(:content)
      item.enc_item_key = nil if item.has_attribute?(:enc_item_key)
      item.auth_hash = nil if item.has_attribute?(:auth_hash)
    end

    def item_params
      params.permit(*permitted_params)
    end

    def permitted_params
      sync_fields
    end

  end
end

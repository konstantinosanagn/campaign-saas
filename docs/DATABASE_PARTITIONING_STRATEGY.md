# Database Partitioning Strategy

## Overview

This document outlines the database partitioning strategy for scaling the Campaign SaaS application as data volume grows. Partitioning is recommended when tables exceed certain size thresholds to improve query performance and manageability.

---

## When to Consider Partitioning

Partition tables when they reach:
- **leads**: 1M+ rows
- **agent_outputs**: 2M+ rows (grows faster as each lead has multiple outputs)
- **campaigns**: 100K+ rows (less critical, but consider if needed)

---

## Recommended Partitioning Strategy

### 1. Leads Table

**Partition by:** `created_at` (date range partitioning)

**Rationale:**
- Leads are created in chronological order
- Most queries filter by date ranges
- Older leads are accessed less frequently
- Easy to archive old partitions

**Implementation:**

```ruby
# Migration: Partition leads table by created_at (monthly partitions)

class PartitionLeadsByDate < ActiveRecord::Migration[8.1]
  def up
    # Create partitioned table
    execute <<-SQL
      CREATE TABLE leads_partitioned (
        LIKE leads INCLUDING ALL
      ) PARTITION BY RANGE (created_at);
    SQL

    # Create partitions for current and next 6 months
    (0..6).each do |month_offset|
      start_date = Date.current.beginning_of_month + month_offset.months
      end_date = start_date + 1.month
      partition_name = "leads_#{start_date.strftime('%Y_%m')}"

      execute <<-SQL
        CREATE TABLE #{partition_name} PARTITION OF leads_partitioned
        FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
      SQL
    end

    # Migrate existing data (requires downtime)
    # execute "INSERT INTO leads_partitioned SELECT * FROM leads;"
    # execute "DROP TABLE leads;"
    # execute "ALTER TABLE leads_partitioned RENAME TO leads;"
  end

  def down
    # Reverse the process
  end
end
```

**Monthly Maintenance:**
- Create new partition for next month
- Optionally drop/archive partitions older than 12-24 months

---

### 2. Agent Outputs Table

**Partition by:** `created_at` (date range partitioning)

**Rationale:**
- Closely related to leads (created at similar times)
- Can be partitioned identically to leads
- Enables parallel processing by time period

**Implementation:**

```ruby
class PartitionAgentOutputsByDate < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE TABLE agent_outputs_partitioned (
        LIKE agent_outputs INCLUDING ALL
      ) PARTITION BY RANGE (created_at);
    SQL

    # Create partitions matching leads partitions
    (0..6).each do |month_offset|
      start_date = Date.current.beginning_of_month + month_offset.months
      end_date = start_date + 1.month
      partition_name = "agent_outputs_#{start_date.strftime('%Y_%m')}"

      execute <<-SQL
        CREATE TABLE #{partition_name} PARTITION OF agent_outputs_partitioned
        FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
      SQL
    end
  end
end
```

---

### 3. Campaigns Table

**Partition by:** `user_id` (hash partitioning)

**Rationale:**
- Less critical than leads/agent_outputs
- Queries are typically scoped by user_id
- Enables better multi-tenant isolation
- Can improve parallel query processing per user

**Implementation:**

```ruby
class PartitionCampaignsByUser < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE TABLE campaigns_partitioned (
        LIKE campaigns INCLUDING ALL
      ) PARTITION BY HASH (user_id);
    SQL

    # Create 8 partitions (adjust based on expected number of users)
    (0..7).each do |partition_number|
      partition_name = "campaigns_partition_#{partition_number}"
      execute <<-SQL
        CREATE TABLE #{partition_name} PARTITION OF campaigns_partitioned
        FOR VALUES WITH (MODULUS 8, REMAINDER #{partition_number});
      SQL
    end
  end
end
```

**Note:** Only implement if campaigns table exceeds 100K rows and performance degrades.

---

## Maintenance Tasks

### Monthly Partition Creation

Create a rake task to automatically create new partitions:

```ruby
# lib/tasks/partitions.rake

namespace :db do
  namespace :partitions do
    desc "Create monthly partitions for next 3 months"
    task create_monthly: :environment do
      (0..2).each do |month_offset|
        start_date = Date.current.beginning_of_month + month_offset.months
        end_date = start_date + 1.month
        
        # Check if partition already exists
        partition_name = "leads_#{start_date.strftime('%Y_%m')}"
        unless ActiveRecord::Base.connection.table_exists?(partition_name)
          ActiveRecord::Base.connection.execute <<-SQL
            CREATE TABLE #{partition_name} PARTITION OF leads
            FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
          SQL
          
          puts "Created partition: #{partition_name}"
        end
      end
    end

    desc "Archive partitions older than 12 months"
    task archive_old: :environment do
      cutoff_date = 12.months.ago.beginning_of_month
      
      # List partitions older than cutoff
      partitions_to_archive = ActiveRecord::Base.connection.execute <<-SQL
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'leads_%' 
        AND tablename < 'leads_#{cutoff_date.strftime('%Y_%m')}'
        ORDER BY tablename;
      SQL
      
      partitions_to_archive.each do |partition|
        partition_name = partition['tablename']
        archive_name = "#{partition_name}_archived"
        
        # Create archive table
        ActiveRecord::Base.connection.execute <<-SQL
          CREATE TABLE #{archive_name} (LIKE #{partition_name} INCLUDING ALL);
          INSERT INTO #{archive_name} SELECT * FROM #{partition_name};
          DROP TABLE #{partition_name};
        SQL
        
        puts "Archived partition: #{partition_name}"
      end
    end
  end
end
```

---

## Query Considerations

### Partition Pruning

PostgreSQL automatically prunes partitions when queries include the partition key:

```ruby
# ✅ Good - partition pruning occurs
Lead.where("created_at >= ?", 1.month.ago)

# ❌ Bad - scans all partitions
Lead.where(company: "Microsoft")  # No partition key filter

# ✅ Better - add partition key filter
Lead.where(company: "Microsoft")
    .where("created_at >= ?", 1.month.ago)
```

### Index Maintenance

- Indexes are created on the partitioned table and automatically apply to all partitions
- Maintenance is easier as you can reindex individual partitions
- Consider partial indexes on active partitions

```ruby
# Create partial index on active partition only
execute <<-SQL
  CREATE INDEX idx_leads_active_stage 
  ON leads_current_month (stage) 
  WHERE stage IN ('queued', 'searched', 'written');
SQL
```

---

## Migration Path

### Phase 1: Preparation (No Downtime)

1. ✅ **Add GIN indexes** on JSONB columns (already implemented)
2. ✅ **Implement batch processing** for leads (already implemented)
3. Monitor table sizes and query performance

### Phase 2: Partitioning Setup (Requires Downtime)

1. **Choose maintenance window** (low traffic period)
2. **Create partitioned table structure**
3. **Migrate data** from existing tables
4. **Update application** to use partitioned tables
5. **Verify** queries and performance

### Phase 3: Ongoing Maintenance

1. **Automate** monthly partition creation (rake task + cron)
2. **Archive** old partitions periodically
3. **Monitor** partition performance and adjust strategy if needed

---

## Performance Benefits

### Before Partitioning
- Full table scans on large tables
- Slow queries as data grows
- Difficult to archive old data

### After Partitioning
- **Partition pruning**: Only scans relevant partitions
- **Parallel processing**: Can query partitions in parallel
- **Easier maintenance**: Drop/archive old partitions
- **Better indexes**: Smaller indexes per partition = faster queries

### Expected Improvements

For a leads table with 10M rows:
- **Query time**: 80-90% reduction for date-range queries
- **Index size**: 70-80% smaller per partition
- **Maintenance**: 90% faster to reindex individual partitions

---

## Monitoring Queries

After partitioning, monitor:

```sql
-- Check partition usage
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE 'leads_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check partition pruning effectiveness
EXPLAIN ANALYZE
SELECT * FROM leads
WHERE created_at >= CURRENT_DATE - INTERVAL '1 month';
```

---

## Alternative: Table Archiving Strategy

If partitioning seems too complex initially, consider:

1. **Archive old data** to separate tables:
   ```ruby
   class ArchiveOldLeads < ActiveRecord::Migration[8.1]
     def up
       create_table :leads_archive_2024 do |t|
         # Copy schema from leads
       end
       
       execute <<-SQL
         INSERT INTO leads_archive_2024
         SELECT * FROM leads
         WHERE created_at < '2025-01-01';
         
         DELETE FROM leads
         WHERE created_at < '2025-01-01';
       SQL
     end
   end
   ```

2. **Use UNION queries** when accessing both active and archived data
3. **Gradually move** to partitioning when ready

---

## Summary

**Current Status:**
- ✅ GIN indexes on JSONB columns (implemented)
- ✅ Batch processing for leads (implemented)
- ⏳ Partitioning (ready for implementation when needed)

**Recommendation:**
- Monitor table sizes monthly
- Implement partitioning when leads table exceeds 1M rows
- Start with leads table, then agent_outputs
- Use monthly date-range partitioning

---

*Last Updated: 2025-12-01*

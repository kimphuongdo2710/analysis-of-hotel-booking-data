# Analysis of Hotel Booking Data (updating...)
## 1. Business Context

You have been hired by a luxury hotel chain to analyze business performance based on booking data from the past 2 years.

The hotel management is facing several business challenges and needs you to find key insights to optimize revenue, reduce cancellations, and improve customer experience.

🛠 Your tasks:

- Answer business questions using data
- Propose strategies to maximize hotel revenue
- Visualize data with BI tools or Python
- Present your findings as a dashboard or presentation

## 2. Materials and Methods
- Tool: **Microsoft SQL Server Management Studio**
- Data Source: Provided by Dứa Data.
- Use SQLAlchemy to connect with MySQL database.
- Time range: for bookings created from 12-02-2023 to 10-02-2025
- Data Limitations:
   1. In table rooms_senior, status "Available" and "Booked" are vague which not clear state which period of this status.

| No. | Table Name | Description |
|----------|----------|----------|
| 1.     | Customers     | Contain information about customers who have previously booked rooms at the hotel     |
| 2.    | Rooms     | Store information about the rooms in the hotel     |
| 3.   | Bookings     | Record the booking history of customers     |
| 4.   | Payments     | Record customers' payments     |
| 5.   | Services     | Contain a list of additional services in the hotel     |
| 6.   | Service_Usage     | Record the services that customers have used in the hotel     |

## 3. Exploratory Data Analysis (EDA)
### 3.1 Data Validation and Transformation
- Create and double check Primary Keys and Foreign Keys from tables:

```
with connection.connect() as conn:
    inspector = inspect(conn)
    tables = inspector.get_table_names()
    
    for table in tables:
        print("\n"f"Table: {table}")
        fks = inspector.get_foreign_keys(table)
        pk = inspector.get_pk_constraint(table)
        print("Primary key(s):", pk['constrained_columns'])
        if fks:
            for fk in fks:
                print(f"  Foreign Key: {fk['constrained_columns']} -> {fk['referred_table']}({fk['referred_columns']})")
        else:
                print("  No foreign keys")
```

- Check the relationships among tables and right below is an output:

```
relations = []

with connection.connect() as conn:
    inspector = inspect(conn)
    tables = inspector.get_table_names()
    
    for table in tables:
        fks = inspector.get_foreign_keys(table)
        for fk in fks:
            relations.append({
                "table": table,
                "column": fk['constrained_columns'],
                "references_table": fk['referred_table'],
                "references_column": fk['referred_columns']
            })

df_rel = pd.DataFrame(relations)
print(df_rel)
```

<div align = "center">
<img width="822" height="169" alt="image" src="https://github.com/user-attachments/assets/f2fcdf01-93e6-4df9-b05c-0e2c897a7123"/>
</div>

### 3.2 Anomaly Detection
| Flag For Review                  | Action Plan                  |
|-----------------------|---------------------------|
| **1,468 bookings** have a ```created_at``` date that is after the ```payment_date```, of which **1,222 are unique bookings**, indicating that some guests made a payment before the booking was officially created.<br><br>→ ***Discussion:*** This situation can occur if a returning guest has an unpaid balance from a previous stay, or due to system cut-off errors, or from data entry, timezone, or software issues. |Double check with the operation staffs, but keep data as it is for now        |
| ***Refund Fraud***: In **507 cases**, payments were made after the bookings had already been canceled.<br><br>→ ***Discussion:*** This could mean one of the following:<br>- The payment was for additional services (such as spa or gym) that may use the same booking_id.<br>To confirm this, we need to check if the hotel uses the same booking_id for these extra services.<br>- If the booking_id is not reused for other services, the payment might represent compensation for the canceled booking.<br>- Otherwise, these cases may indicate an error in the hotel management system. |Double check with the operation staffs, but keep data as it is for now        |
| ***Cancelation Fraud***: There are **1,702 cases** where guests checked into their rooms even though their bookings were marked as cancelled. |Remove these cases out of the dataset      |
| ***Double Bookings*** (same check_in date, same check_out date and same rooms): There are **6 cases** where the same room has been booked for overlapping periods. |Remove these cases out of the dataset      |
   
### 3.2 Data Exploration
- Using CTEs to measure the Occupancy Rate for each Room Type:

```
WITH booking_count AS (
		SELECT  rooms.room_type, COUNT(*) AS booked_count
		FROM dbo.bookings_senior bks
		LEFT JOIN dbo.rooms_senior rooms
			ON bks.room_id = rooms.room_id
		WHERE bks.status = 'Confirmed'
		GROUP BY rooms.room_type), 

	total_booking_count AS (
		SELECT SUM(booked_count) AS total_booked
		FROM booking_count)

SELECT room_type, CAST(ROUND(booked_count*100.0/total_booked, 2) AS DECIMAL(10,1)) AS occupancy_rate
FROM booking_count
CROSS JOIN total_booking_count
ORDER BY occupancy_rate ASC
```
## 4. Key Business Insights
###  4.1 Hotel Booking Performance
**Findings**
Occupancy Rate for each Room Type

![Image](https://github.com/kimphuongdo2710/analysis-of-hotel-booking-data/blob/main/asset/Screenshot%202025-09-25%20121348.png)

- Standard Type has the lowest occupancy rate. 

**Recommentions**
###  4.2 Dynamic Pricing Optimization
###  4.3 Customer Segmentation & Churn Prediction
###  4.4 Anomaly Detection

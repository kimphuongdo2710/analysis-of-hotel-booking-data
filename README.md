# Analysis of Hotel Booking Data (updating...)
## 1. Business Context

You have been hired by a luxury hotel chain to analyze business performance based on booking data from the past 2 years.

The hotel management is facing several business challenges and needs you to find key insights to optimize revenue, reduce cancellations, and improve customer experience.

🛠 Your tasks:

✔️ Answer business questions using data

✔️ Propose strategies to maximize hotel revenue

✔️ Visualize data with BI tools or Python

✔️ Present your findings as a dashboard or presentation

## 2. Materials and Methods
- Tool: **Microsoft SQL Server Management Studio**
- Data Source: Provided by Dứa Data.

| No. | Table Name | Description |
|----------|----------|----------|
| 1.     | Customers     | Contain information about customers who have previously booked rooms at the hotel     |
| 2.    | Rooms     | Store information about the rooms in the hotel     |
| 3.   | Bookings     | Record the booking history of customers     |
| 4.   | Payments     | Record customers' payments     |
| 5.   | Services     | Contain a list of additional services in the hotel     |
| 6.   | Service_Usage     | Record the services that customers have used in the hotel     |

## 3. Exploratory Data Analysis (EDA)
Using CTEs to measure the Occupancy Rate for each Room Type:

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

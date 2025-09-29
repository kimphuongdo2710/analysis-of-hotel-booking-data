-- Check which database is connected
SELECT DB_NAME() AS CURRENTDATABASE
-- Change into the relevant database
USE hotel_revenue_tracking_10Mar25
GO

--Analysis started from here
SELECT *
FROM dbo.rooms_senior

SELECT *
FROM dbo.hotel_revenue_tracking_10Mar25.bookings_senior

-- 1. **Hiệu suất đặt phòng**:
	-- Phòng nào có tỷ lệ lấp đầy thấp nhất? total_booked_room by types/total_booked_all_types

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

SELECT TOP 1 room_type, CAST(ROUND(booked_count*100.0/total_booked, 2) AS DECIMAL(10,1)) AS occupancy_rate
FROM booking_count
CROSS JOIN total_booking_count
ORDER BY occupancy_rate ASC

	-- Khách hàng thường đặt phòng theo mùa hay có xu hướng cụ thể?
-- Segment season by date on data of bookings

SELECT *
FROM dbo.bookings_senior

SELECT 
	CASE 
		WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
		WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
		WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
		WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
	END AS season,
	COUNT(*) AS booking_count
FROM dbo.bookings_senior
WHERE status = 'Confirmed'
GROUP BY 
	CASE 
		WHEN month(check_in) IN (1,2,3) THEN 'Winter'
		WHEN month(check_in) IN (4,5,6) THEN 'Spring'
		WHEN month(check_in) IN (7,8,9) THEN 'Summer'
		WHEN month(check_in) IN (10,11,12) THEN 'Autumn'
	END
ORDER BY booking_count DESC

	-- Tỷ lệ lấp đầy phòng theo tháng là bao nhiêu?
 
WITH booked_count AS (
	SELECT MONTH(check_in) AS month, YEAR(check_in) AS year, COUNT(*) AS booked_count
	FROM bookings_senior bk
	LEFT JOIN rooms_senior rm
		ON bk.room_id = rm.room_id
	WHERE bk.status = 'Confirmed'
	GROUP BY MONTH(check_in), YEAR(check_in)),

	total_booked_count AS (
	SELECT year, SUM(booked_count) AS total_booked_count
	FROM booked_count
	GROUP BY year)

SELECT month, booked_count.year, CAST(ROUND(booked_count*100.0/total_booked_count,2) AS DECIMAL (10,2)) AS occupancy_rate
FROM booked_count
CROSS JOIN total_booked_count
ORDER BY 2, 1

	-- Tỷ lệ lấp đầy phòng theo mùa là bao nhiêu?

WITH booked_count AS (
	SELECT season, COUNT(*) AS booked_count
	FROM (SELECT CASE
			WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
			WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
			WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
			WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
			END AS season
	FROM bookings_senior
	WHERE status = 'Confirmed') AS subquery
	GROUP BY season),

	total_booked_count AS (
	SELECT SUM(booked_count) AS total_booked_count
	FROM booked_count)

SELECT season, CAST(ROUND(booked_count*100.0/total_booked_count,2) AS DECIMAL(10,2)) AS occupancy_rate
FROM booked_count
CROSS JOIN total_booked_count
ORDER BY 2


-- 1A. Hướng Phát Hiện Bất Thường (Anomaly Detection) --> Một báo cáo phát hiện gian lận trong đặt phòng & thanh toán
	-- Có giao dịch thanh toán nào bất thường không?
	-- bất thường 1: Thanh toán sau khi hủy (Refund Fraud)

SELECT b.booking_id, p.payment_id, b.check_in, p.payment_date, b.status
FROM dbo.payments_senior p
JOIN bookings_senior b
	ON p.booking_id = b.booking_id
WHERE check_in < payment_date
 AND status IN ('Cancelled', 'Pending')

	-- bất thường 2: Đặt phòng trùng lặp (Duplicate Bookings) - Result: NO
SELECT c.customer_id, COUNT(*) AS booking_count
FROM bookings_senior b
JOIN customers_senior c
	ON b.customer_id = c.customer_id
GROUP BY c.customer_id, check_in, check_out
HAVING COUNT(*) > 1

	-- bất thường 3: Kiểm tra thanh toán nhiều lần từ cùng một thẻ (Multiple Payments) - Result: No card_number data
	
SELECT b.booking_id, p.card_number, COUNT(p.card_number) AS card_used_count
FROM dbo.payments_senior p
JOIN bookings_senior b
	ON p.booking_id = b.booking_id
HAVING COUNT(p.card_number) >3

	-- bất thường 4: Tìm những khách đặt phòng nhưng không đến (No-Show Fraud) - Result: 106 rows

SELECT c.customer_id, SUM(p.amount) AS total_paid, MIN(b.check_in) AS first_check_in, MAX(b.check_out) AS last_check_out 
		, COUNT(*) AS cancelled_count
FROM bookings_senior b
JOIN customers_senior c
	ON b.customer_id = c.customer_id
JOIN payments_senior p
	ON b.booking_id = p.booking_id
WHERE status = 'Cancelled'
GROUP BY c.customer_id
HAVING COUNT(*) > 3

	-- bất thường 5: Tìm những booking hủy đặt phòng nhưng lại phát sinh giao dịch trong cùng số booking hủy 
				--> Result: 1,258 bookings

	WITH CTE_cancelled AS (
		SELECT b.customer_id, b.booking_id, SUM(s.quantity) AS total_quantity
		FROM bookings_senior b
		LEFT JOIN service_usage_senior s
			ON b.booking_id = s.booking_id
		WHERE status = 'Cancelled'
		GROUP BY b.customer_id, b.booking_id
		HAVING SUM(quantity) > 0 )

	SELECT 'Summary' AS type,
			COUNT(DISTINCT customer_id) AS customer_id, 
			COUNT(DISTINCT booking_id) AS booking_id, 
			SUM(total_quantity) AS total_quantity
	FROM CTE_cancelled

	UNION ALL

	SELECT 'Detailed' AS type,
			CAST(b.customer_id AS VARCHAR), 
			CAST(b.booking_id AS VARCHAR), 
			SUM(s.quantity) AS total_quantity
	FROM bookings_senior b
	LEFT JOIN service_usage_senior s
		ON b.booking_id = s.booking_id
	WHERE status = 'Cancelled'
	GROUP BY b.customer_id, b.booking_id
	HAVING SUM(s.quantity) > 0 

	
----------------------------------------

-- 2. **Doanh thu & Dịch vụ** - Kết quả mong đợi: Một bảng phân tích tổng quan về hiệu suất đặt phòng, doanh thu, khách hàng và dịch vụ
    -- 2.1 Những dịch vụ nào được sử dụng nhiều nhất?

SELECT TOP 1 s.service_name, su.service_id, SUM(quantity) AS total_quantity
FROM service_usage_senior su
LEFT JOIN services_senior s
	ON su.service_id = s.service_id
GROUP BY s.service_name, su.service_id
ORDER BY SUM(quantity) DESC

	-- 2.2 Dịch vụ nào mang lại doanh thu cao nhất?
SELECT TOP 1 s.service_name, su.service_id, SUM(total_price) AS total_revenue
FROM service_usage_senior su
LEFT JOIN services_senior s
	ON su.service_id = s.service_id
GROUP BY s.service_name, su.service_id
ORDER BY SUM(total_price) DESC

    2.4 Khách sạn có phụ thuộc quá nhiều vào một nhóm khách hàng cụ thể không?
	-- 2.4.1 Tính Tỷ Lệ Đóng Góp của Nhóm Khách Hàng Chính --> Result: 16.14%, means Khách hàng phân bố đồng đều, ít phụ thuộc vào nhóm khách hàng lớn.

	WITH customer_booking_count AS (
	SELECT b.customer_id, COUNT(*) AS customer_booking_count
	FROM bookings_senior b
	GROUP BY b.customer_id),

	total_booking_count AS (
	SELECT SUM(customer_booking_count) AS total_booking_count
	FROM customer_booking_count),

	top_customer AS(
	SELECT TOP 10 PERCENT customer_id, customer_booking_count
	FROM customer_booking_count
	ORDER BY customer_booking_count DESC),

	top_customer_bk_count AS(
	SELECT SUM(customer_booking_count) AS total_top_bk
	FROM top_customer)

	SELECT CAST(ROUND(total_top_bk*100.0/total_booking_count, 2) AS DECIMAL(10,2)) AS customer_contr
	FROM total_booking_count, top_customer_bk_count

-- 2.4.2 Chỉ Số Phân Bố Doanh Thu (Revenue Concentration Ratio)

WITH 
	customer_revenue AS(
	SELECT c.customer_id, SUM(p.amount) AS revenue
	FROM bookings_senior b
	JOIN customers_senior c
		ON b.customer_id = c.customer_id
	JOIN payments_senior p
		ON b.booking_id = p.booking_id
	GROUP BY c.customer_id),

	top_customer AS(
	SELECT TOP 10 PERCENT customer_id, revenue
	FROM customer_revenue
	ORDER BY revenue DESC),

	top_customer_revenue AS(
	SELECT SUM(revenue) AS total_top_revenue
	FROM top_customer),

	total_revenue AS (
	SELECT SUM(amount) AS total_revenue
	FROM payments_senior)


SELECT CAST(ROUND(total_top_revenue*100.0/total_revenue, 2) AS DECIMAL(10,2)) AS customer_contr_revenue
FROM top_customer_revenue, total_revenue


	-- Phòng nào có doanh thu cao nhất?

SELECT TOP 1 room_type, SUM(amount) AS revenue
FROM bookings_senior b
LEFT JOIN rooms_senior r
	ON r.room_id = b.room_id
LEFT JOIN payments_senior p
	ON b.booking_id = p.booking_id
GROUP BY room_type
ORDER BY 2 DESC


--3. **Tối ưu hóa giá phòng** - Kết quả mong đợi: Một mô hình đề xuất giá phòng theo thời gian để tối đa hóa doanh thu
    -- Giá phòng hiện tại có ảnh hưởng đến lượng đặt phòng không?

	-- Check number_of_bookings and avg_price
SELECT r.room_type, COUNT(booking_id) AS room_nite, CAST(AVG(r.price_per_night) AS DECIMAL(10,2)) AS avg_price
FROM bookings_senior b
LEFT JOIN rooms_senior r
	ON b.room_id = r.room_id
GROUP BY r.room_type
ORDER BY avg_price DESC

	-- Check occupancy rate and avg_price
WITH booking_count AS (
	SELECT  rooms.room_type, COUNT(*) AS booked_count, CAST(AVG(r.price_per_night) AS DECIMAL (10,2)) AS avg_price
	FROM dbo.bookings_senior bks
	LEFT JOIN dbo.rooms_senior rooms
		ON bks.room_id = rooms.room_id
	LEFT JOIN rooms_senior r
		ON bks.room_id = r.room_id
	WHERE bks.status = 'Confirmed'
	GROUP BY rooms.room_type), 

    total_booking_count AS (
	SELECT SUM(booked_count) AS total_booked
	FROM booking_count)

SELECT room_type, CAST(ROUND(booked_count*100.0/total_booked, 2) AS DECIMAL(10,1)) AS occupancy_rate, avg_price
FROM booking_count
CROSS JOIN total_booking_count
ORDER BY occupancy_rate ASC

-- Nên điều chỉnh giá theo mùa hay không?

-- Phân tích số lượng đặt phòng theo mùa & room_type --> Analysis: Summer-hot season, 

WITH season AS (
		SELECT b.booking_id, r.room_type,
			CASE 
				WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
				WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
				WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
				WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
			END AS season
		FROM bookings_senior b
		JOIN rooms_senior r ON b.room_id = r.room_id 
		WHERE b.status = 'Confirmed'),

	component_booked AS (
		SELECT season, room_type, COUNT(*) AS component_booked
		FROM season
		GROUP BY season, room_type)

SELECT s.season, r.room_type,COUNT(b.booking_id), CAST(AVG(price_per_night) AS DECIMAL (10,2)) AS avg_price, 
		CAST((component_booked*100.0/SUM(component_booked) OVER (PARTITION BY s.season)) AS DECIMAL (10,2)) AS occupancy_rate
FROM bookings_senior b
JOIN rooms_senior r ON r.room_id = b.room_id
JOIN season s ON b.booking_id = s.booking_id
JOIN component_booked cb ON s.season = cb.season
GROUP BY s.season, r.room_type, cb.component_booked
ORDER BY 4 DESC

SELECT CASE 
			WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
			WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
			WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
			WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
		END AS season, room_type, price_per_night
FROM bookings_senior b
JOIN rooms_senior r ON b.room_id = r.room_id
WHERE b.status = 'confirmed'
ORDER BY 1

SELECT CASE 
			WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
			WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
			WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
			WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
		END AS season, room_type, COUNT(*) AS booked_count
FROM bookings_senior b
JOIN rooms_senior r ON b.room_id = r.room_id
WHERE b.status = 'confirmed'
GROUP BY CASE 
			WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
			WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
			WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
			WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
		END, room_type
ORDER BY 3 DESC


	-- Phân tích số lượng đặt phòng theo mùa --> Analysis: Summer-hot season, 
SELECT year, season,
		COUNT(CASE WHEN status = 'Confirmed' THEN 1 ELSE NULL END) AS confirmed_count,
		COUNT(CASE WHEN status = 'Pending' THEN 1 ELSE NULL END) AS pending_count,
		COUNT(CASE WHEN status = 'Cancelled' THEN 1 ELSE NULL END) AS cancelled_count,
		COUNT(*) AS total_count,
		CAST(AVG(price_per_night) AS DECIMAL(10,2)) AS avr_price
FROM (SELECT year(b.created_at) AS year,
		CASE 
			WHEN MONTH(check_in) IN (1,2,3) THEN 'Winter'
			WHEN MONTH(check_in) IN (4,5,6) THEN 'Spring'
			WHEN MONTH(check_in) IN (7,8,9) THEN 'Summer'
			WHEN MONTH(check_in) IN (10,11,12) THEN 'Autumn'
		END AS season, b.status, r.price_per_night
		FROM bookings_senior b
		JOIN rooms_senior r ON b.room_id = r.room_id
		) AS subquery
GROUP BY season, year
ORDER BY 1,2

	-- Phân tích số lượng đặt phòng theo tháng  
	--> RESULT: Low season: Feb, Mar, Aug, Nov, Dec. Mid-season: Apr, May, Sep, Oct. High season: Jan, Jun, Jul.

WITH total_count AS (
		SELECT FORMAT(created_at, 'MM/yyyy') AS created_at, COUNT(booking_id) AS total_count
		FROM bookings_senior b
		GROUP BY FORMAT(created_at, 'MM/yyyy'))

SELECT created_at, total_count, AVG(total_count) OVER () AS avr_count
FROM total_count
ORDER BY RIGHT(created_at,4) + LEFT(created_at,2)

	-- Mức giá tối ưu để tối đa hóa lợi nhuận là bao nhiêu?

--4. **Tỷ lệ hủy phòng**:
    -- Bao nhiêu % đặt phòng bị hủy? Tỷ lệ hủy đặt phòng trung bình là bao nhiêu?

WITH temp_cancelled AS (
		SELECT COUNT(*) AS cancelled_count
		FROM bookings_senior
		WHERE status = 'Cancelled'),

	total_booking AS (
		SELECT COUNT(*) AS total_bks_count
		FROM bookings_senior)

SELECT cancelled_count*100.0/total_bks_count
FROM temp_cancelled, total_booking

SELECT r.room_type, 
		CAST(COUNT(CASE WHEN b.status = 'Cancelled' THEN 1 END)*100.0 / COUNT(*) AS DECIMAL(10,2)) AS cancellation_rate,
		AVG(CAST(COUNT(CASE WHEN b.status = 'Cancelled' THEN 1 END)*100.0 / COUNT(*) AS DECIMAL(10,2))) OVER() AS avr_cancl_rate
FROM bookings_senior b
LEFT JOIN rooms_senior r
	ON b.room_id = r.room_id
GROUP BY r.room_type

    -- Có lý do nào phổ biến dẫn đến việc hủy phòng không?

--5. Hướng Dự Đoán & Phân Loại Khách Hàng (Customer Segmentation & Churn Prediction) 
	--> Một bảng phân tích nhóm khách hàng kèm theo chiến lược cá nhân hóa ưu đãi
	-- Ai là khách hàng VIP? --> 	Find top 10 customers having the highest expense in room & services.

SELECT TOP 10 c.customer_id, COUNT(b.booking_id) AS booking_count, 
		SUM(amount) AS room_expense, SUM(total_price) AS service_expense,
		(SUM(amount) + SUM(total_price)) AS total_expense
FROM bookings_senior b
LEFT JOIN customers_senior c
	ON b.customer_id = c.customer_id
JOIN payments_senior p
	ON b.booking_id = p.booking_id
JOIN service_usage_senior s
	ON b.booking_id = s.booking_id
GROUP BY c.customer_id
ORDER BY total_expense DESC

SELECT c.customer_id, COUNT(b.booking_id) AS booking_count
FROM bookings_senior b
LEFT JOIN customers_senior c
	ON b.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY 2 DESC
	-- 5.2 Có bao nhiêu khách hàng có nguy cơ rời bỏ khách sạn?

--> Number of customers having over 3 times of cancellation.

SELECT COUNT(*) AS total_customers_with_cancellations
FROM(SELECT customer_id, 
		COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_count,
		COUNT(*) AS total_count
FROM bookings_senior b
GROUP BY customer_id
HAVING COUNT(CASE WHEN status = 'cancelled' THEN 1 END)>=3) AS subquery
	
	-- 5.3 Nhóm khách nào sử dụng dịch vụ nhiều nhất?

SELECT r.room_type, COALESCE(SUM(s.quantity),0) AS total_quantity, 
		COALESCE(SUM(total_price),0) AS total_spend
FROM bookings_senior b
INNER JOIN service_usage_senior s
	ON b.booking_id = s.booking_id
INNER JOIN rooms_senior r
	ON b.room_id = r.room_id
WHERE b.status = 'confirmed'
GROUP BY r.room_type
ORDER BY total_spend DESC

	
	-- 5.4 Có bao nhiêu % khách quay lại đặt phòng? --> Results: 100% returned guests
WITH booking_count AS (	SELECT customer_id, COUNT(booking_id) AS booking_count
						FROM bookings_senior
						GROUP BY customer_id),
	customer_count AS (	SELECT COUNT(DISTINCT customer_id) AS customer_count
						FROM booking_count
						WHERE booking_count > 1 ),
	all_customer_count AS (SELECT COUNT(DISTINCT customer_id) AS total_customers
						FROM bookings_senior)

SELECT CAST(customer_count*100.0/total_customers AS DECIMAL (10,2)) AS percent_returned_csm
FROM customer_count CROSS JOIN all_customer_count



#What is the total amount each customer spent at the restaurant?
SELECT 
    s.customer_id,
    SUM(m.price) AS total_amount_spent
FROM 
    sales s
JOIN 
    menu m ON s.product_id = m.product_id
GROUP BY 
    s.customer_id
ORDER BY 
    s.customer_id;
#How many days has each customer visited the restaurant?
SELECT 
    customer_id,
    COUNT(DISTINCT order_date) AS days_visited
FROM 
    sales
GROUP BY 
    customer_id
ORDER BY 
    customer_id;
#What was the first item from the menu purchased by each customer?
WITH first_orders AS (
    SELECT 
        customer_id,
        product_id,
        order_date,
        RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_rank
    FROM 
        sales
)
SELECT DISTINCT
    fo.customer_id,
    m.product_name AS first_purchased_item
FROM 
    first_orders fo
JOIN 
    menu m ON fo.product_id = m.product_id
WHERE 
    fo.order_rank = 1
ORDER BY 
    fo.customer_id;
#What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
    m.product_name,
    COUNT(s.product_id) AS total_purchases
FROM 
    sales s
JOIN 
    menu m ON s.product_id = m.product_id
GROUP BY 
    m.product_name
ORDER BY 
    total_purchases DESC
LIMIT 1;
#Which item was the most popular for each customer?
WITH most_popular AS (
  SELECT 
    sales.customer_id, 
    menu.product_name, 
    COUNT(menu.product_id) AS order_count,
    DENSE_RANK() OVER (
      PARTITION BY sales.customer_id 
      ORDER BY COUNT(sales.customer_id) DESC) AS rank1
  FROM dannys_diner.menu
  INNER JOIN dannys_diner.sales
    ON menu.product_id = sales.product_id
  GROUP BY sales.customer_id, menu.product_name
)

SELECT 
  customer_id, 
  product_name, 
  order_count
FROM most_popular 
WHERE rank1 = 1;
#Which item was purchased first by the customer after they became a member?
WITH joined_as_member AS (
  SELECT
    members.customer_id, 
    sales.product_id,
    ROW_NUMBER() OVER (
      PARTITION BY members.customer_id
      ORDER BY sales.order_date) AS row_num
  FROM dannys_diner.members
  INNER JOIN dannys_diner.sales
    ON members.customer_id = sales.customer_id
    AND sales.order_date > members.join_date
)

SELECT 
  customer_id, 
  product_name 
FROM joined_as_member
INNER JOIN dannys_diner.menu
  ON joined_as_member.product_id = menu.product_id
WHERE row_num = 1
ORDER BY customer_id ASC;
#Which item was purchased just before the customer became a member?
WITH purchased_prior_member AS (
  SELECT 
    members.customer_id, 
    sales.product_id,
    ROW_NUMBER() OVER (
      PARTITION BY members.customer_id
      ORDER BY sales.order_date DESC) AS rank1
  FROM dannys_diner.members
  INNER JOIN dannys_diner.sales
    ON members.customer_id = sales.customer_id
    AND sales.order_date < members.join_date
)

SELECT 
  p_member.customer_id, 
  menu.product_name 
FROM purchased_prior_member AS p_member
INNER JOIN dannys_diner.menu
  ON p_member.product_id = menu.product_id
WHERE rank1 = 1
ORDER BY p_member.customer_id ASC;
#What is the total items and amount spent for each member before they became a member?
SELECT 
    s.customer_id,
    COUNT(*) AS total_items_purchased,
    SUM(m.price) AS total_amount_spent
FROM 
    sales s
JOIN 
    members mem ON s.customer_id = mem.customer_id
JOIN 
    menu m ON s.product_id = m.product_id
WHERE 
    s.order_date < mem.join_date
GROUP BY 
    s.customer_id
ORDER BY 
    s.customer_id;
#If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT 
    s.customer_id,
    SUM(
        CASE 
            WHEN m.product_name = 'sushi' THEN m.price * 20  -- 2x multiplier (10 × 2)
            ELSE m.price * 10                                -- Regular points
        END
    ) AS total_points
FROM 
    sales s
JOIN 
    menu m ON s.product_id = m.product_id
GROUP BY 
    s.customer_id
ORDER BY 
    s.customer_id;
#In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH member_purchases AS (
    SELECT 
        s.customer_id,
        m.product_name,
        m.price,
        s.order_date,
        mem.join_date,
        -- First week bonus period (join date + 6 days)
        CASE 
            WHEN s.order_date BETWEEN mem.join_date AND DATE_ADD(mem.join_date, INTERVAL 6 DAY) THEN 1
            ELSE 0
        END AS is_first_week,
        -- January cutoff
        CASE 
            WHEN s.order_date <= '2021-01-31' THEN 1
            ELSE 0
        END AS is_january
    FROM 
        sales s
    JOIN 
        members mem ON s.customer_id = mem.customer_id
    JOIN 
        menu m ON s.product_id = m.product_id
    WHERE 
        s.customer_id IN ('A', 'B')
)
SELECT 
    customer_id,
    SUM(
        CASE 
            WHEN is_first_week = 1 THEN price * 20  -- 2x points for all items in first week
            WHEN product_name = 'sushi' THEN price * 20  -- 2x points for sushi anytime
            ELSE price * 10  -- Standard points
        END * is_january  -- Only count January purchases
    ) AS total_points
FROM 
    member_purchases
GROUP BY 
    customer_id
ORDER BY 
    customer_id;
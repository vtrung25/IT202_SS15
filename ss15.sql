/* =========================================================
   MINI SOCIAL NETWORK - PHIÊN BẢN ĐƠN GIẢN
   - Trigger, Transaction, Stored Procedure (MySQL 8.0+)
   ========================================================= */

drop database if exists mini_social_network;
create database mini_social_network
  character set utf8mb4
  collate utf8mb4_unicode_ci;
use mini_social_network;

/* =========================
   TABLES (CORE)
   ========================= */

create table users (
  user_id     int auto_increment primary key,
  username    varchar(50)  not null unique,
  password    varchar(255) not null,
  email       varchar(100) not null unique,
  created_at  datetime     not null default current_timestamp
);

create table posts (
  post_id     int auto_increment primary key,
  user_id     int not null,
  content     text not null,
  like_count  int not null default 0,
  created_at  datetime not null default current_timestamp,
  foreign key (user_id) references users(user_id) on delete cascade
);

create table comments (
  comment_id  int auto_increment primary key,
  post_id     int not null,
  user_id     int not null,
  content     text not null,
  created_at  datetime not null default current_timestamp,
  foreign key (post_id) references posts(post_id) on delete cascade,
  foreign key (user_id) references users(user_id) on delete cascade
);

create table likes (
  user_id     int not null,
  post_id     int not null,
  created_at  datetime not null default current_timestamp,
  primary key (user_id, post_id),
  foreign key (user_id) references users(user_id) on delete cascade,
  foreign key (post_id) references posts(post_id) on delete cascade
);

create table friends (
  user_id     int not null,
  friend_id   int not null,
  status      varchar(20) not null default 'pending',
  created_at  datetime not null default current_timestamp,
  primary key (user_id, friend_id),
  foreign key (user_id) references users(user_id) on delete cascade,
  foreign key (friend_id) references users(user_id) on delete cascade
);

/* =========================
   LOG TABLES
   ========================= */

create table user_log (
  log_id     int auto_increment primary key,
  user_id    int not null,
  action     varchar(50) not null,
  log_time   datetime not null default current_timestamp,
  details    varchar(255) null
);

create table post_log (
  log_id     int auto_increment primary key,
  post_id    int null,
  user_id    int null,
  action     varchar(50) not null,
  log_time   datetime not null default current_timestamp,
  details    varchar(255) null
);

create table like_log (
  log_id     int auto_increment primary key,
  user_id    int not null,
  post_id    int not null,
  action     varchar(20) not null,
  log_time   datetime not null default current_timestamp
);

create table friend_log (
  log_id        int auto_increment primary key,
  user_id       int not null,
  friend_id     int not null,
  action        varchar(50) not null,
  status_after  varchar(20) null,
  log_time      datetime not null default current_timestamp
);


/* =========================================================
   BÀI 1: ĐĂNG KÝ THÀNH VIÊN
   - Stored Procedure: sp_register_user
   - Trigger: trg_users_after_insert (ghi log)
   ========================================================= */

delimiter $$

-- Trigger bài 1: Log khi đăng ký user
create trigger trg_users_after_insert
after insert on users
for each row
begin
  insert into user_log(user_id, action, details)
  values (new.user_id, 'register', concat('username=', new.username));
end$$

-- Procedure bài 1: Đăng ký thành viên
create procedure sp_register_user(
  in p_username varchar(50),
  in p_password varchar(255),
  in p_email    varchar(100)
)
begin
  if p_username is null or trim(p_username) = '' then
    signal sqlstate '45000' set message_text = 'LOI: Username khong duoc rong';
  elseif exists (select 1 from users where username = p_username) then
    signal sqlstate '45000' set message_text = 'LOI: Username da ton tai';
  elseif exists (select 1 from users where email = p_email) then
    signal sqlstate '45000' set message_text = 'LOI: Email da ton tai';
  else
    insert into users(username, password, email)
    values (p_username, p_password, p_email);
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 2: ĐĂNG BÀI VIẾT
   - Stored Procedure: sp_create_post
   - Trigger: trg_posts_after_insert (ghi log)
   ========================================================= */

delimiter $$

-- Trigger bài 2: Log khi tạo bài viết
create trigger trg_posts_after_insert
after insert on posts
for each row
begin
  insert into post_log(post_id, user_id, action)
  values (new.post_id, new.user_id, 'create_post');
end$$

-- Procedure bài 2: Đăng bài viết
create procedure sp_create_post(
  in p_user_id int,
  in p_content text
)
begin
  if not exists (select 1 from users where user_id = p_user_id) then
    signal sqlstate '45000' set message_text = 'LOI: User khong ton tai';
  elseif p_content is null or trim(p_content) = '' then
    signal sqlstate '45000' set message_text = 'LOI: Noi dung bai viet khong duoc rong';
  else
    insert into posts(user_id, content) values (p_user_id, p_content);
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 3: THÍCH BÀI VIẾT
   - Stored Procedure: sp_like_post, sp_unlike_post
   - Trigger: trg_likes_after_insert (tăng like_count + log)
   - Trigger: trg_likes_after_delete (giảm like_count + log)
   ========================================================= */

delimiter $$

-- Trigger bài 3: Tăng like_count khi like
create trigger trg_likes_after_insert
after insert on likes
for each row
begin
  update posts set like_count = like_count + 1 where post_id = new.post_id;
  insert into like_log(user_id, post_id, action) values (new.user_id, new.post_id, 'like');
end$$

-- Trigger bài 3: Giảm like_count khi unlike
create trigger trg_likes_after_delete
after delete on likes
for each row
begin
  update posts set like_count = like_count - 1 where post_id = old.post_id;
  insert into like_log(user_id, post_id, action) values (old.user_id, old.post_id, 'unlike');
end$$

-- Procedure bài 3: Like bài viết
create procedure sp_like_post(
  in p_user_id int,
  in p_post_id int
)
begin
  if exists (select 1 from likes where user_id = p_user_id and post_id = p_post_id) then
    signal sqlstate '45000' set message_text = 'LOI: Ban da like bai viet nay roi';
  else
    insert into likes(user_id, post_id) values (p_user_id, p_post_id);
  end if;
end$$

-- Procedure bài 3: Unlike bài viết
create procedure sp_unlike_post(
  in p_user_id int,
  in p_post_id int
)
begin
  if not exists (select 1 from likes where user_id = p_user_id and post_id = p_post_id) then
    signal sqlstate '45000' set message_text = 'LOI: Ban chua like bai viet nay';
  else
    delete from likes where user_id = p_user_id and post_id = p_post_id;
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 4: GỬI LỜI MỜI KẾT BẠN
   - Stored Procedure: sp_send_friend_request
   - Trigger: trg_friends_after_insert (ghi log)
   ========================================================= */

delimiter $$

-- Trigger bài 4: Log khi gửi lời mời kết bạn
create trigger trg_friends_after_insert
after insert on friends
for each row
begin
  insert into friend_log(user_id, friend_id, action, status_after)
  values (new.user_id, new.friend_id, 'request_sent', new.status);
end$$

-- Procedure bài 4: Gửi lời mời kết bạn
create procedure sp_send_friend_request(
  in p_sender_id   int,
  in p_receiver_id int
)
begin
  if p_sender_id = p_receiver_id then
    signal sqlstate '45000' set message_text = 'LOI: Khong the tu ket ban voi chinh minh';
  elseif not exists (select 1 from users where user_id = p_sender_id) then
    signal sqlstate '45000' set message_text = 'LOI: Nguoi gui khong ton tai';
  elseif not exists (select 1 from users where user_id = p_receiver_id) then
    signal sqlstate '45000' set message_text = 'LOI: Nguoi nhan khong ton tai';
  elseif exists (select 1 from friends where user_id = p_sender_id and friend_id = p_receiver_id) then
    signal sqlstate '45000' set message_text = 'LOI: Da gui loi moi roi';
  elseif exists (select 1 from friends where user_id = p_receiver_id and friend_id = p_sender_id) then
    signal sqlstate '45000' set message_text = 'LOI: Nguoi nay da gui loi moi cho ban';
  else
    insert into friends(user_id, friend_id, status)
    values (p_sender_id, p_receiver_id, 'pending');
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 5: CHẤP NHẬN LỜI MỜI KẾT BẠN
   - Stored Procedure: sp_accept_friend_request (Transaction)
   - Trigger: trg_friends_after_update (ghi log)
   ========================================================= */

delimiter $$

-- Trigger bài 5: Log khi cập nhật trạng thái bạn bè
create trigger trg_friends_after_update
after update on friends
for each row
begin
  if old.status <> new.status then
    insert into friend_log(user_id, friend_id, action, status_after)
    values (new.user_id, new.friend_id, 'status_changed', new.status);
  end if;
end$$

-- Procedure bài 5: Chấp nhận lời mời kết bạn
create procedure sp_accept_friend_request(
  in p_sender_id   int,
  in p_receiver_id int
)
begin
  if not exists (
    select 1 from friends 
    where user_id = p_sender_id and friend_id = p_receiver_id and status = 'pending'
  ) then
    signal sqlstate '45000' set message_text = 'LOI: Khong co loi moi ket ban de chap nhan';
  else
    start transaction;
    
    -- Cập nhật trạng thái thành accepted
    update friends
    set status = 'accepted'
    where user_id = p_sender_id and friend_id = p_receiver_id;
    
    -- Tạo bản ghi ngược (quan hệ 2 chiều)
    insert into friends(user_id, friend_id, status)
    values (p_receiver_id, p_sender_id, 'accepted');
    
    commit;
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 6: QUẢN LÝ MỐI QUAN HỆ BẠN BÈ
   - Stored Procedure: sp_update_friendship (Transaction + Rollback)
   - Stored Procedure: sp_remove_friendship (Transaction + Rollback)
   ========================================================= */

delimiter $$

-- Procedure bài 6a: Cập nhật trạng thái bạn bè
create procedure sp_update_friendship(
  in p_user_id     int,
  in p_friend_id   int,
  in p_new_status  varchar(20),
  in p_test_rollback int
)
begin
  declare v_count int default 0;
  
  select count(*) into v_count from friends
  where user_id = p_user_id and friend_id = p_friend_id;
  
  if v_count = 0 then
    signal sqlstate '45000' set message_text = 'LOI: Khong tim thay quan he ban be';
  else
    start transaction;
    
    -- Cập nhật cả 2 chiều
    update friends set status = p_new_status
    where user_id = p_user_id and friend_id = p_friend_id;
    
    update friends set status = p_new_status
    where user_id = p_friend_id and friend_id = p_user_id;
    
    if p_test_rollback = 1 then
      rollback;
    else
      commit;
    end if;
  end if;
end$$

-- Procedure bài 6b: Xóa quan hệ bạn bè
create procedure sp_remove_friendship(
  in p_user_id   int,
  in p_friend_id int,
  in p_test_rollback int
)
begin
  declare v_count int default 0;
  
  select count(*) into v_count from friends
  where (user_id = p_user_id and friend_id = p_friend_id)
     or (user_id = p_friend_id and friend_id = p_user_id);
  
  if v_count = 0 then
    signal sqlstate '45000' set message_text = 'LOI: Khong tim thay quan he ban be de xoa';
  else
    start transaction;
    
    -- Xóa cả 2 chiều
    delete from friends
    where (user_id = p_user_id and friend_id = p_friend_id)
       or (user_id = p_friend_id and friend_id = p_user_id);
    
    if p_test_rollback = 1 then
      rollback;
    else
      commit;
    end if;
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 7: QUẢN LÝ XÓA BÀI VIẾT
   - Stored Procedure: sp_delete_post (Transaction + Rollback)
   - Trigger: trg_posts_before_delete (ghi log)
   ========================================================= */

delimiter $$

-- Trigger bài 7: Log khi xóa bài viết
create trigger trg_posts_before_delete
before delete on posts
for each row
begin
  insert into post_log(post_id, user_id, action)
  values (old.post_id, old.user_id, 'delete_post');
end$$

-- Procedure bài 7: Xóa bài viết
create procedure sp_delete_post(
  in p_post_id int,
  in p_user_id int,
  in p_test_rollback int
)
begin
  declare v_owner_id int;
  
  select user_id into v_owner_id from posts where post_id = p_post_id;
  
  if v_owner_id is null then
    signal sqlstate '45000' set message_text = 'LOI: Bai viet khong ton tai';
  elseif v_owner_id <> p_user_id then
    signal sqlstate '45000' set message_text = 'LOI: Ban khong phai chu bai viet, khong the xoa';
  else
    start transaction;
    
    -- Xóa likes, comments, post
    delete from likes where post_id = p_post_id;
    delete from comments where post_id = p_post_id;
    delete from posts where post_id = p_post_id;
    
    if p_test_rollback = 1 then
      rollback;
    else
      commit;
    end if;
  end if;
end$$

delimiter ;


/* =========================================================
   BÀI 8: QUẢN LÝ XÓA TÀI KHOẢN NGƯỜI DÙNG
   - Stored Procedure: sp_delete_user (Transaction + Rollback)
   ========================================================= */

delimiter $$

-- Procedure bài 8: Xóa tài khoản
create procedure sp_delete_user(
  in p_user_id int,
  in p_test_rollback int
)
begin
  if not exists (select 1 from users where user_id = p_user_id) then
    signal sqlstate '45000' set message_text = 'LOI: User khong ton tai';
  else
    start transaction;
    
    -- Xóa friends, user (cascade xóa posts, comments, likes)
    delete from friends where user_id = p_user_id or friend_id = p_user_id;
    delete from users where user_id = p_user_id;
    
    if p_test_rollback = 1 then
      rollback;
    else
      commit;
    end if;
  end if;
end$$

delimiter ;


/* =========================================================
                    DEMO VÀ KIỂM TRA
   ========================================================= */


/* =========================================================
   BÀI 1: DEMO ĐĂNG KÝ THÀNH VIÊN
   ========================================================= */
select '========== BAI 1: DANG KY THANH VIEN ==========' as '';

-- 1.1: Đăng ký 4 user thành công
select '-- 1.1: Dang ky 4 user thanh cong:' as '';
call sp_register_user('alice', 'pass1', 'alice@example.com');
call sp_register_user('bob', 'pass2', 'bob@example.com');
call sp_register_user('charlie', 'pass3', 'charlie@example.com');
call sp_register_user('diana', 'pass4', 'diana@example.com');

select '-- Ket qua bang users:' as '';
select * from users;
select '-- Ket qua bang user_log:' as '';
select * from user_log;

-- 1.2: Test lỗi trùng username
select '-- 1.2: Test loi trung username (bo comment de test):' as '';
-- call sp_register_user('alice', 'xxx', 'alice2@example.com');

-- 1.3: Test lỗi trùng email
select '-- 1.3: Test loi trung email (bo comment de test):' as '';
-- call sp_register_user('newuser', 'xxx', 'bob@example.com');

-- 1.4: Test lỗi username rỗng
select '-- 1.4: Test loi username rong (bo comment de test):' as '';
-- call sp_register_user('', 'xxx', 'test@example.com');


/* =========================================================
   BÀI 2: DEMO ĐĂNG BÀI VIẾT
   ========================================================= */
select '========== BAI 2: DANG BAI VIET ==========' as '';

-- 2.1: Đăng 5 bài viết thành công
select '-- 2.1: Dang 5 bai viet thanh cong:' as '';
call sp_create_post(1, 'Hello world from Alice!');
call sp_create_post(1, 'Alice second post');
call sp_create_post(2, 'Bob first post');
call sp_create_post(2, 'Bob sharing something');
call sp_create_post(3, 'Charlie is here');

select '-- Ket qua bang posts:' as '';
select * from posts;
select '-- Ket qua bang post_log:' as '';
select * from post_log;

-- 2.2: Test lỗi content rỗng
select '-- 2.2: Test loi content rong (bo comment de test):' as '';
-- call sp_create_post(1, '');

-- 2.3: Test lỗi user không tồn tại
select '-- 2.3: Test loi user khong ton tai (bo comment de test):' as '';
-- call sp_create_post(999, 'Test post');


/* =========================================================
   BÀI 3: DEMO THÍCH BÀI VIẾT
   ========================================================= */
select '========== BAI 3: THICH BAI VIET ==========' as '';

-- Thêm comments để test bài 7
insert into comments(post_id, user_id, content) values
  (1, 2, 'Nice post, Alice!'),
  (1, 3, 'Hello Alice'),
  (2, 3, 'Good one!');

-- 3.1: Like thành công
select '-- 3.1: Like bai viet thanh cong:' as '';
call sp_like_post(2, 1);  -- bob likes post 1
call sp_like_post(3, 1);  -- charlie likes post 1
call sp_like_post(4, 1);  -- diana likes post 1
call sp_like_post(1, 3);  -- alice likes post 3

select '-- Kiem tra like_count tang:' as '';
select post_id, content, like_count from posts;

-- 3.2: Test lỗi like trùng
select '-- 3.2: Test loi like trung (bo comment de test):' as '';
-- call sp_like_post(2, 1);

-- 3.3: Unlike thành công
select '-- 3.3: Unlike thanh cong (bob unlike post 1):' as '';
call sp_unlike_post(2, 1);

select '-- Kiem tra like_count giam:' as '';
select post_id, content, like_count from posts;

-- 3.4: Test lỗi unlike khi chưa like
select '-- 3.4: Test loi unlike khi chua like (bo comment de test):' as '';
-- call sp_unlike_post(2, 1);

select '-- Ket qua bang likes:' as '';
select * from likes;
select '-- Ket qua bang like_log:' as '';
select * from like_log;


/* =========================================================
   BÀI 4: DEMO GỬI LỜI MỜI KẾT BẠN
   ========================================================= */
select '========== BAI 4: GUI LOI MOI KET BAN ==========' as '';

-- 4.1: Gửi lời mời thành công
select '-- 4.1: Gui loi moi ket ban thanh cong:' as '';
call sp_send_friend_request(1, 2);  -- alice -> bob
call sp_send_friend_request(1, 3);  -- alice -> charlie
call sp_send_friend_request(4, 1);  -- diana -> alice

select '-- Ket qua bang friends:' as '';
select * from friends;
select '-- Ket qua bang friend_log:' as '';
select * from friend_log;

-- 4.2: Test lỗi tự gửi cho mình
select '-- 4.2: Test loi tu gui cho minh (bo comment de test):' as '';
-- call sp_send_friend_request(1, 1);

-- 4.3: Test lỗi gửi trùng
select '-- 4.3: Test loi gui trung (bo comment de test):' as '';
-- call sp_send_friend_request(1, 2);

-- 4.4: Test lỗi đã có lời mời ngược
select '-- 4.4: Test loi da co loi moi nguoc (bo comment de test):' as '';
-- call sp_send_friend_request(2, 1);


/* =========================================================
   BÀI 5: DEMO CHẤP NHẬN LỜI MỜI KẾT BẠN
   ========================================================= */
select '========== BAI 5: CHAP NHAN LOI MOI KET BAN ==========' as '';

-- 5.1: Chấp nhận thành công
select '-- 5.1: Bob chap nhan loi moi cua Alice:' as '';
call sp_accept_friend_request(1, 2);

select '-- Kiem tra ca 2 chieu deu accepted:' as '';
select * from friends where (user_id = 1 and friend_id = 2) or (user_id = 2 and friend_id = 1);

-- 5.2: Test lỗi chấp nhận lần nữa
select '-- 5.2: Test loi chap nhan lan nua (bo comment de test):' as '';
-- call sp_accept_friend_request(1, 2);

-- 5.3: Test lỗi không có lời mời
select '-- 5.3: Test loi khong co loi moi (bo comment de test):' as '';
-- call sp_accept_friend_request(3, 4);

select '-- Ket qua bang friends:' as '';
select * from friends;
select '-- Ket qua bang friend_log:' as '';
select * from friend_log;


/* =========================================================
   BÀI 6: DEMO QUẢN LÝ MỐI QUAN HỆ BẠN BÈ
   ========================================================= */
select '========== BAI 6: QUAN LY MOI QUAN HE BAN BE ==========' as '';

-- Chấp nhận thêm lời mời để test
call sp_accept_friend_request(1, 3);  -- charlie chấp nhận alice

-- 6.1: Test ROLLBACK khi cập nhật
select '-- 6.1: Test ROLLBACK khi cap nhat trang thai:' as '';
select '-- Truoc khi rollback:' as '';
select * from friends where user_id in (1,3) and friend_id in (1,3);

call sp_update_friendship(1, 3, 'pending', 1);  -- test rollback

select '-- Sau khi rollback (du lieu KHONG doi):' as '';
select * from friends where user_id in (1,3) and friend_id in (1,3);

-- 6.2: Test ROLLBACK khi xóa
select '-- 6.2: Test ROLLBACK khi xoa quan he:' as '';
select '-- Truoc khi rollback:' as '';
select * from friends where user_id in (1,2) and friend_id in (1,2);

call sp_remove_friendship(1, 2, 1);  -- test rollback

select '-- Sau khi rollback (du lieu KHONG bi xoa):' as '';
select * from friends where user_id in (1,2) and friend_id in (1,2);

-- 6.3: Xóa quan hệ thành công
select '-- 6.3: Xoa quan he alice-bob thanh cong:' as '';
call sp_remove_friendship(1, 2, 0);

select '-- Ket qua sau khi xoa:' as '';
select * from friends;


/* =========================================================
   BÀI 7: DEMO QUẢN LÝ XÓA BÀI VIẾT
   ========================================================= */
select '========== BAI 7: QUAN LY XOA BAI VIET ==========' as '';

-- 7.1: Xem dữ liệu trước khi xóa
select '-- 7.1: Du lieu truoc khi xoa post 1:' as '';
select '-- Posts:' as '';
select * from posts where post_id = 1;
select '-- Comments cua post 1:' as '';
select * from comments where post_id = 1;
select '-- Likes cua post 1:' as '';
select * from likes where post_id = 1;

-- 7.2: Test lỗi không phải chủ bài viết
select '-- 7.2: Test loi bob xoa bai cua alice (bo comment de test):' as '';
-- call sp_delete_post(1, 2, 0);

-- 7.3: Test ROLLBACK
select '-- 7.3: Test ROLLBACK khi xoa bai viet:' as '';
call sp_delete_post(1, 1, 1);

select '-- Sau rollback - bai viet VAN CON:' as '';
select * from posts where post_id = 1;

-- 7.4: Xóa thành công
select '-- 7.4: Alice xoa post 1 thanh cong:' as '';
call sp_delete_post(1, 1, 0);

select '-- Kiem tra du lieu sau khi xoa:' as '';
select '-- Posts (post 1 da bi xoa):' as '';
select * from posts;
select '-- Comments (cua post 1 da bi xoa):' as '';
select * from comments;
select '-- Likes (cua post 1 da bi xoa):' as '';
select * from likes;
select '-- Post_log:' as '';
select * from post_log;


/* =========================================================
   BÀI 8: DEMO QUẢN LÝ XÓA TÀI KHOẢN NGƯỜI DÙNG
   ========================================================= */
select '========== BAI 8: QUAN LY XOA TAI KHOAN ==========' as '';

-- 8.1: Xem dữ liệu của diana trước khi xóa
select '-- 8.1: Du lieu cua diana (user_id=4) truoc khi xoa:' as '';
select '-- User:' as '';
select * from users where user_id = 4;
select '-- Friends:' as '';
select * from friends where user_id = 4 or friend_id = 4;

-- 8.2: Test ROLLBACK
select '-- 8.2: Test ROLLBACK khi xoa user:' as '';
call sp_delete_user(4, 1);

select '-- Sau rollback - user VAN CON:' as '';
select * from users where user_id = 4;

-- 8.3: Xóa thành công
select '-- 8.3: Xoa diana thanh cong:' as '';
call sp_delete_user(4, 0);

select '-- Kiem tra du lieu sau khi xoa:' as '';
select '-- Users (diana da bi xoa):' as '';
select * from users;
select '-- Friends (lien quan diana da bi xoa):' as '';
select * from friends;


/* =========================================================
   KẾT QUẢ CUỐI CÙNG
   ========================================================= */
select '========== KET QUA CUOI CUNG ==========' as '';

select '-- USERS:' as '';
select * from users;

select '-- POSTS:' as '';
select * from posts;

select '-- COMMENTS:' as '';
select * from comments;

select '-- LIKES:' as '';
select * from likes;

select '-- FRIENDS:' as '';
select * from friends;

select '-- USER_LOG:' as '';
select * from user_log;

select '-- POST_LOG:' as '';
select * from post_log;

select '-- LIKE_LOG:' as '';
select * from like_log;

select '-- FRIEND_LOG:' as '';
select * from friend_log;

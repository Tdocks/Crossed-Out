-- Seed content
insert into public.passages (book, chapter, verse_start, verse_end, translation, text, topics, tone) values
('Proverbs',3,5,6,'WEB','Trust in Yahweh with all your heart, and don''t lean on your own understanding. In all your ways acknowledge him, and he will make your paths straight.','{trust,guidance,finance,anxiety}','comfort'),
('Philippians',4,6,7,'WEB','In nothing be anxious, but in everything, by prayer and petition with thanksgiving, let your requests be made known to God. And the peace of God, which surpasses all understanding, will guard your hearts and your thoughts in Christ Jesus.','{anxiety,peace,prayer}','comfort'),
('John',16,33,null,'WEB','I have told you these things, that in me you may have peace. In the world you have trouble; but cheer up! I have overcome the world.','{peace,trouble,hope}','encouragement'),
('Psalms',23,1,3,'WEB','Yahweh is my shepherd; I shall lack nothing. He makes me lie down in green pastures. He leads me beside still waters. He restores my soul.','{rest,provision,peace}','comfort'),
('Isaiah',41,10,null,'WEB','Don''t you be afraid, for I am with you. Don''t be dismayed, for I am your God. I will strengthen you. Yes, I will help you. Yes, I will uphold you with the right hand of my righteousness.','{fear,strength,presence}','encouragement'),
('Matthew',6,33,34,'WEB','But seek first God''s Kingdom and his righteousness; and all these things will be given to you as well. Therefore don''t be anxious for tomorrow.','{priorities,anxiety,finance}','instruction'),
('Jeremiah',29,11,null,'WEB','For I know the thoughts that I think toward you, says Yahweh, thoughts of peace, and not of evil, to give you hope and a future.','{purpose,hope,future}','encouragement'),
('Romans',8,28,null,'WEB','We know that all things work together for good for those who love God, for those who are called according to his purpose.','{purpose,trust,hope}','encouragement'),
('Psalms',46,10,null,'WEB','Be still, and know that I am God.','{rest,peace,presence}','comfort'),
('James',1,5,null,'WEB','But if any of you lacks wisdom, let him ask of God, who gives to all liberally and without reproach, and it will be given to him.','{wisdom,guidance,decisions}','instruction'),
('1 Peter',5,7,null,'WEB','Casting all your worries on him, because he cares for you.','{anxiety,care,trust}','comfort'),
('Hebrews',11,1,null,'WEB','Now faith is assurance of things hoped for, proof of things not seen.','{faith,hope}','instruction');

insert into public.churches (name, city, rating, style, distance_miles, is_live, viewers, accent) values
('Elevation Church','Charlotte, NC',4.8,'Contemporary',1.2,true,2100,'red'),
('The Belonging Co','Nashville, TN',4.7,'Worship',2.1,false,null,'blue'),
('Freedom Church','Charlotte, NC',4.6,'Contemporary',3.3,false,null,'olive'),
('City Church','Charlotte, NC',4.5,'Bible Teaching',4.8,false,null,'gold'),
('Bethel Church','Redding, CA',4.7,'Worship',null,false,null,'blue'),
('Saddleback Church','Lake Forest, CA',4.6,'Teaching',null,false,null,'olive'),
('Hillsong Church','Global',4.5,'Contemporary',null,false,null,'gold');

insert into public.live_services (church_id, title, starts_in, service_time, is_live)
select id, 'Sunday Gathering', null, null, true from public.churches where name='Elevation Church';
insert into public.live_services (church_id, title, starts_in, service_time, is_live)
select id, 'Sunday Gathering', '18m', null, false from public.churches where name='Bethel Church';
insert into public.live_services (church_id, title, starts_in, service_time, is_live)
select id, 'Sunday Gathering', '45m', null, false from public.churches where name='Saddleback Church';
insert into public.live_services (church_id, title, starts_in, service_time, is_live)
select id, 'Global Service', null, '9:00 AM', false from public.churches where name='Hillsong Church';

insert into public.give_projects (title, org, raised, goal, date_range) values
('Feed the Homeless','Charlotte, NC',4820,10000,null),
('Mission Trip to Kenya','Jul 12 – Jul 24',3150,5000,'Jul 12 – Jul 24');

insert into public.prayer_requests (author_name, body, prayed_count) values
('Jessica L.','Please pray for my dad''s surgery on Friday. Thank you!',12);

insert into public.community_posts (author_name, kind, body, verse_ref, verse_text, heart_count) values
('Mark D.','verse_share','','John 16:33','I have told you these things, so that in me you may have peace. In this world you will have trouble. But take heart! I have overcome the world.',18);

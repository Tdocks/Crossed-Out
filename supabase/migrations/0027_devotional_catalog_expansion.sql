-- 0027: Devotional catalog expansion — 66 additional authored devotionals
-- (target: 100 total published with 0016's 3 + 0026's 31).
--
-- Pure content: no mechanics/RPC changes. The preference-aware picker from
-- 0026 (_pick_devotional) automatically benefits from the larger pool.
--
-- Same conventions as 0026:
--   * book strings follow BibleBooks.all ("Psalms" plural, "1 Peter",
--     "Song of Solomon", "Revelation"); verse_ref is the display form
--     ("Psalm 23:1").
--   * body ~100–140 words, pastorally written, grace-first; commonly
--     misused verses are treated in context (e.g. Philippians 4:13).
--   * style ∈ reflective|study|encouragement|practical|prayer, spread.
--   * Idempotent: every insert guarded on title; re-running is a no-op.
--
-- Coverage: 3 each for the 18 highest-need focus areas, 2 each for the
-- remaining 6 — every focus area gains depth.

-- ============ anxiety / rest_peace ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Do not fear, I am with you',
   'Isaiah 41:10', 'Isaiah', 41, 10, null,
   'God''s command not to fear is never left hanging on its own — it comes with reasons: I am with you; I am your God; I will strengthen you, help you, uphold you. Five promises stacked under one instruction. Notice that none of them promise the scary thing will disappear. They promise Presence and support inside it. Fear shrinks when it stops being faced alone. Whatever today holds, you do not walk into it unaccompanied; the hand that upholds you is, in Isaiah''s phrase, a righteous right hand — strong and for you.',
   'Which of the five promises in this verse do you most need to hold onto today?',
   'encouragement', 'anxiety', array['fear','presence','strength']),
  ('When anxiety multiplies',
   'Psalm 94:19', 'Psalms', 94, 19, null,
   'The psalmist describes anxiety honestly: cares multiplying within — one worry breeding four more, the way anxious thoughts actually behave at 2 a.m. But the verse holds a second multiplication: Your consolation brings joy to my soul. God''s comfort is not a single dose; it rises to meet the volume of the anxiety. Scripture never shames the anxious for the multiplying; it points them to a consolation that multiplies faster. Bring the whole tangled pile, not just the presentable worry on top.',
   'What does the "multiplying" of your anxious thoughts look like lately — and have you brought the whole pile to God, or just the top one?',
   'reflective', 'anxiety', array['comfort','honesty','consolation']),
  ('Consider the birds',
   'Matthew 6:26', 'Matthew', 6, 26, null,
   'Jesus'' therapy for worry is strangely concrete: look at the birds. They do not sow, reap, or store — yet your heavenly Father feeds them. The argument moves from lesser to greater: if God sustains sparrows, will He not sustain you, who are worth more than many of them? This is not a call to stop working; birds still fly and forage. It is a call to stop assuming everything rests on you. Today, when worry rises, actually do what Jesus said: step outside, watch something feathered and unbothered, and remember whose care you live under.',
   'When did you last literally stop to "consider the birds"? What might that unhurried look teach your worry?',
   'practical', 'anxiety', array['provision','worry','creation']),
  ('My presence will go with you',
   'Exodus 33:14', 'Exodus', 33, 14, null,
   'Moses faced an impossible assignment and told God plainly: if Your presence does not go with us, do not send us. God''s answer — My presence will go with you, and I will give you rest — ties two things together we often separate: presence and rest. Real rest is not primarily a schedule change; it is company. You can sleep ten hours and wake unrested if you carry everything alone. Before the calendar audit, try Moses'' prayer: refuse to go anywhere today without Him, and let rest come from being accompanied.',
   'Where are you trying to go this week that you haven''t yet asked God to accompany?',
   'reflective', 'rest_peace', array['presence','rest','accompaniment']),
  ('Kept in perfect peace',
   'Isaiah 26:3', 'Isaiah', 26, 3, null,
   'You will keep in perfect peace the one whose mind is stayed on You. The Hebrew doubles the word: shalom shalom — peace, peace. But notice the mechanism: a mind STAYED, leaned, propped like a ladder against a wall. Peace here is not the absence of noise but the result of where the mind habitually rests its weight. Every anxious spiral is a mind leaning on something that cannot hold it. The practice is small and repeatable: catch the lean, move the ladder. Trust is where the propping happens.',
   'What does your mind lean on by default under stress — and what would "moving the ladder" look like today?',
   'study', 'rest_peace', array['peace','mind','trust']),
  ('He gives to His beloved sleep',
   'Psalm 127:2', 'Psalms', 127, 2, null,
   'It is vain, the psalm says, to rise early and stay up late eating the bread of anxious toil — for He gives to His beloved sleep. Sleep is presented as a gift, not a concession. Every night you lie down, you rehearse a theology: the world will be held together for the next eight hours without your supervision. Workaholism is often unbelief wearing a badge of diligence. Tonight, going to bed on time can be an act of worship — a confession that God stays up so you don''t have to.',
   'What would going to bed on time tonight say to God — and about Him?',
   'practical', 'rest_peace', array['sleep','toil','trust'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ grief / forgiveness ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Every tear, counted and ended',
   'Revelation 21:4', 'Revelation', 21, 4, null,
   'The Bible does not end with grief explained; it ends with grief ENDED. He will wipe away every tear from their eyes, and death shall be no more, nor mourning, nor crying, nor pain. Notice the tenderness of the image — not a decree issued from a throne, but a hand on a face. Your sorrow is not a permanent resident; it is a tenant with an eviction date. That does not shrink today''s ache, but it does give it a horizon. You are not grieving toward nothing. You are grieving toward the morning when grieving itself dies.',
   'How does knowing grief has an end-date change how you carry it today — without rushing it?',
   'encouragement', 'grief', array['hope','heaven','tears']),
  ('You keep my tears',
   'Psalm 56:8', 'Psalms', 56, 8, null,
   'Father, David says You keep count of my tossings and put my tears in Your bottle — that not one of them falls unrecorded. So I bring You the tears I have hidden from everyone else: the ones in the car, the ones at night, the ones that surprise me in ordinary moments. If You keep them, they must matter to You. I don''t need You to explain my loss today. I need to know You were present for every tear of it. You were. Hold what I cannot carry, and stay near while I cry. Amen.',
   'What tears have you been hiding — even from God?',
   'prayer', 'grief', array['lament','tears','remembrance']),
  ('Comfort that travels',
   '2 Corinthians 1:3-4', '2 Corinthians', 1, 3, 4,
   'Paul calls God the Father of mercies and God of ALL comfort, who comforts us in all our affliction — and then adds the surprising purpose: so that we can comfort others with the comfort we ourselves received. Nothing you have suffered is wasted. The specific consolation God works into your grief becomes equipment: one day you will sit with someone in the same valley, and your presence will carry weight no untested sympathy can. This does not explain your loss. But it does promise your loss will not be sterile.',
   'Who might one day need the exact comfort you are receiving now?',
   'study', 'grief', array['comfort','purpose','ministry']),
  ('Bear with, forgive, repeat',
   'Colossians 3:13', 'Colossians', 3, 13, null,
   'Paul gives the church two verbs for life together: bear with one another, and forgive whatever grievance you have — as the Lord forgave you. "Bearing with" handles the daily friction that doesn''t rise to the level of sin: the habits, the quirks, the tone. Forgiveness handles the real wounds. Many relationships die not from one great betrayal but from a refusal to do either — everything becomes a grievance, and no grievance is released. The standard is not fairness. It is "as the Lord forgave you": first, fully, and at His own expense.',
   'Which do you owe someone right now — patience with a difference, or forgiveness of a wound? They need different responses.',
   'practical', 'forgiveness', array['patience','community','grace']),
  ('East from west',
   'Psalm 103:12', 'Psalms', 103, 12, null,
   'As far as the east is from the west — a distance that never closes, because you can travel east forever without arriving at west — so far has He removed our transgressions from us. Some of us cannot forgive others because we have never actually received forgiveness ourselves; we keep our own sins close, reviewing the file. But God has removed what you keep retrieving. The sin you rehearse at night is, in His accounting, on the far side of an infinite distance. Let it be as far from your self-talk as He has put it from His.',
   'What forgiven sin do you keep retrieving — and what would it mean to leave it where God put it?',
   'reflective', 'forgiveness', array['pardon','shame','distance']),
  ('Leave your gift at the altar',
   'Matthew 5:23-24', 'Matthew', 5, 23, 24,
   'Jesus imagines a worshiper mid-ritual who remembers a brother has something against him — and tells him to leave the gift at the altar and go be reconciled FIRST. Notice the direction: this is not about the grudge you hold, but the one held against you. Reconciliation outranks religious performance on God''s priority list. Worship resumes after the repair attempt, not instead of it. You cannot control whether the other person receives you. You can control whether you went.',
   'Is there someone who has something against you that God might be sending you toward this week?',
   'practical', 'forgiveness', array['reconciliation','worship','initiative'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ purpose / relationships ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('What the Lord requires',
   'Micah 6:8', 'Micah', 6, 8, null,
   'Micah''s audience wondered what would satisfy God — rivers of oil? Thousands of rams? The answer deflates all religious inflation: He has shown you what is good. Do justice, love kindness, walk humbly with your God. Purpose, it turns out, is not hidden; it is stated. Before any question of career or calling, there is a life-shape available to you today: fairness in your dealings, mercy loved (not merely dispensed), and a daily walk kept humble and close. If you do those three things where you already are, you are not waiting for your purpose. You are living it.',
   'Which of the three — justice, kindness, humility — is thinnest in your life right now?',
   'study', 'purpose', array['justice','mercy','humility']),
  ('All things — for good?',
   'Romans 8:28', 'Romans', 8, 28, null,
   'This verse is often quoted carelessly, as if everything that happens is good. Paul says something sturdier: in ALL things — including genuinely evil, senseless things — God WORKS for the good of those who love Him. The good is defined two verses later: being conformed to the image of His Son. God is not calling your loss good; He is refusing to let it have the last word. Like a master weaver working a torn thread into a larger pattern, He wastes nothing. You may not see the pattern for years. The promise is that there is one.',
   'Where do you need to trust that God is working, without pretending the hard thing is good?',
   'study', 'purpose', array['providence','suffering','hope']),
  ('Labor that is not in vain',
   '1 Corinthians 15:58', '1 Corinthians', 15, 58, null,
   'Paul closes his great resurrection chapter with a surprising application: therefore, be steadfast, immovable, always abounding in the work of the Lord — knowing your labor in the Lord is not in vain. Because resurrection is real, nothing done for Christ evaporates. The unnoticed kindness, the class taught to distracted kids, the prayers over a wandering child — all of it is seed in ground that death cannot keep. Purposelessness says "nothing I do matters." Resurrection says "nothing you do in Him is lost."',
   'What faithful work have you been tempted to quit because it seems to accomplish nothing?',
   'encouragement', 'purpose', array['resurrection','perseverance','work']),
  ('A friend for the hard season',
   'Proverbs 17:17', 'Proverbs', 17, 17, null,
   'A friend loves at all times, and a brother is born for adversity. Notice when friendship proves itself: not in the highlight-reel seasons but in adversity — the diagnosis, the divorce, the failure. The proverb invites two questions. Who has earned the right to see your hard season? And whose hard season are you showing up for? Deep friendship is not found; it is built, mostly by staying when leaving would be easier. Be the friend this proverb describes, and you will rarely lack one.',
   'Who is in adversity right now that you could simply show up for this week?',
   'practical', 'relationships', array['friendship','loyalty','adversity']),
  ('Love, described precisely',
   '1 Corinthians 13:4-7', '1 Corinthians', 13, 4, 7,
   'Paul''s famous description of love contains no feelings — only behaviors. Patient. Kind. Not envying, not boasting, not arrogant or rude, not insisting on its own way, not irritable or resentful. A useful exercise: read the list and replace the word "love" with your own name. Where the sentence becomes untrue, you have found this week''s assignment. Love, in Scripture, is less a weather system that happens to you and more a craft you practice on actual people, one patient and unirritable moment at a time.',
   'Which phrase in Paul''s list is least true with your name in it — and toward whom?',
   'reflective', 'relationships', array['love','character','practice']),
  ('Iron sharpens iron',
   'Proverbs 27:17', 'Proverbs', 27, 17, null,
   'Iron sharpens iron, and one man sharpens another. Sharpening is friction by design — sparks, pressure, edges meeting. The proverb assumes what we often avoid: that the relationships which grow you will sometimes be uncomfortable. A friend who only agrees with you is a whetstone made of butter. Do you have anyone with permission to contradict you, question your choices, and tell you hard truths in love? If not, the missing piece of your growth may not be information but a person.',
   'Who has real permission to sharpen you — and if no one does, who could you give it to?',
   'practical', 'relationships', array['honesty','growth','friendship'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ marriage / parenting ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Love that covers',
   '1 Peter 4:8', '1 Peter', 4, 8, null,
   'Above all, Peter writes, keep loving one another earnestly, for love covers a multitude of sins. Covering is not denial — Peter knew betrayal firsthand. It is the daily choice not to itemize. In a marriage, two sinners share a roof; there will always be a multitude to work with. Love decides which offenses need a conversation and which need a quiet burial. Many marriages suffocate under perfect scorekeeping. Earnest love keeps short accounts and a bad memory for pettiness. What might you simply cover today — freely, without a receipt?',
   'What small offense could you bury today instead of filing it?',
   'encouragement', 'marriage', array['covering','grace','endurance']),
  ('A cord of three strands',
   'Ecclesiastes 4:9-12', 'Ecclesiastes', 4, 9, 12,
   'Two are better than one, the Teacher says: they help each other up, keep each other warm, defend each other. Then the arithmetic turns odd — a cord of THREE strands is not quickly broken. Jewish and Christian readers have long seen the third strand as God Himself woven into the union. Marriages braided around shared prayer, shared worship, and shared dependence on Him hold under strain that snaps a two-strand rope. If your marriage feels frayed, the repair may not start with each other. It may start with re-braiding the third strand.',
   'When did you last pray together — and what would it take to braid that back in this week?',
   'study', 'marriage', array['unity','prayer','strength']),
  ('As Christ loved the church',
   'Ephesians 5:25', 'Ephesians', 5, 25, null,
   'Husbands, love your wives as Christ loved the church and gave Himself up for her. Whatever debates surround this chapter, the verb assigned here is unambiguous: self-sacrifice, modeled on a cross. Christ''s love was not a mood; it was a costly, initiating, covenant-keeping act for people at their least lovable. Applied to marriage — by either spouse — the question shifts from "am I getting what I need?" to "what would laying myself down look like today?" Marriages transform when someone goes first.',
   'What would "going first" in sacrificial love look like in your marriage this week?',
   'reflective', 'marriage', array['sacrifice','covenant','initiative']),
  ('Start them on the way',
   'Proverbs 22:6', 'Proverbs', 22, 6, null,
   'Train up a child in the way he should go, and when he is old he will not depart from it. A proverb is a general truth, not an ironclad guarantee — grown children make real choices, and faithful parents of prodigals have not failed. But the direction stands: the grooves worn in childhood — what was prayed about, laughed about, repented of, prioritized — shape the road a life tends to travel. You are not writing your child''s ending. You are laying track. Lay it toward home, and trust the God who runs to meet returners.',
   'What "groove" is your daily family life wearing right now — and is it one you''d want them to return to?',
   'study', 'parenting', array['formation','habits','trust']),
  ('Children are a heritage',
   'Psalm 127:3', 'Psalms', 127, 3, null,
   'Children are a heritage from the LORD, offspring a reward from Him. In a culture where children can feel like projects to optimize or obstacles to schedule around, the psalm recovers the older word: gift. Gifts are received, not controlled; enjoyed, not merely managed. Tonight, look at your child — including the exhausting one — and practice seeing what the psalm sees: not a report card of your parenting, but a person entrusted to you by God, on purpose. Gratitude changes the tone of a home faster than technique.',
   'When did you last enjoy your child rather than manage them? What would that look like today?',
   'reflective', 'parenting', array['gift','gratitude','presence']),
  ('Let the children come',
   'Mark 10:14', 'Mark', 10, 14, null,
   'The disciples saw children as interruptions to important ministry; Jesus was indignant — with the disciples. Let the children come to me, do not hinder them, for to such belongs the kingdom of God. Parents can hinder without meaning to: by making faith feel like behavior management, by treating church as performance, by having no room for a child''s odd, honest questions. Your job is mostly traffic direction — keeping the way to Jesus unobstructed. Welcome the interrupting question. It may be the day''s most important conversation.',
   'Is anything about how faith works in your home making Jesus harder for your kids to approach?',
   'practical', 'parenting', array['welcome','questions','kingdom'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ temptation / addiction ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Resist, and he flees',
   'James 4:7', 'James', 4, 7, null,
   'James gives the order of operations precisely: submit yourselves to God — THEN resist the devil, and he will flee from you. We usually try resisting without submitting, white-knuckling temptation with an unsurrendered heart, and wonder why we lose. Resistance draws its power from allegiance: a life placed under God''s authority has weight behind its "no." And note the promise — the enemy flees not from your strength but from Whose you are. Begin today''s battles one step earlier than the battlefield: with surrender.',
   'Are you trying to resist something you haven''t first surrendered to God?',
   'study', 'temptation', array['submission','resistance','victory']),
  ('Watch and pray',
   'Matthew 26:41', 'Matthew', 26, 41, null,
   'In Gethsemane Jesus gave the sleepy disciples a strategy for the hour of trial: watch and pray, that you may not enter into temptation — the spirit is willing, but the flesh is weak. Two verbs, both preventive. Watching means knowing your patterns: the hour, the mood, the app, the aisle where you always fall. Praying means asking for help BEFORE the moment, not just apologizing after. Most temptation is lost early, in the unwatchful drift. Name your Gethsemane hours, and meet them awake and already praying.',
   'What time, place, or mood is your most predictable point of temptation — and what would "watching" it look like?',
   'practical', 'temptation', array['vigilance','prayer','weakness']),
  ('The word hidden deep',
   'Psalm 119:11', 'Psalms', 119, 11, null,
   'I have hidden Your word in my heart, that I might not sin against You. The psalmist describes ammunition stored in advance — Scripture memorized so it is present in the moment of temptation, the way Jesus answered the desert tempter with "It is written." A verse on a shelf cannot help you at midnight; a verse in the heart can. Choose one verse that speaks directly to your recurring struggle. Write it down. Say it aloud until it says itself. You are not just learning words; you are arming the moment.',
   'Which single verse will you hide in your heart this week for your most recurring temptation?',
   'practical', 'temptation', array['memorization','scripture','preparation']),
  ('Free indeed',
   'John 8:36', 'John', 8, 36, null,
   'So if the Son sets you free, you will be free indeed. Jesus spoke to people who insisted they had never been slaves — blind to their bondage. Addiction knows better; it has felt the chain. Here is the gospel''s claim: freedom is not primarily achieved but received, won by Someone else and given. Recovery still involves work — meetings, honesty, amends, one day at a time — but it rests on a foundation effort cannot pour: you are already someone the Son intends to free. Walk today''s steps as a person whose freedom has been purchased, not one still negotiating the price.',
   'What changes if you fight today not FOR freedom but FROM it?',
   'encouragement', 'addiction', array['freedom','grace','recovery']),
  ('Up from the pit',
   'Psalm 40:1-2', 'Psalms', 40, 1, 2,
   'David''s testimony has the shape every addict recognizes: I waited patiently for the LORD; He inclined to me and heard my cry. He drew me up from the pit of destruction, out of the miry bog, and set my feet upon a rock. Notice the passive verbs — drawn up, set, established. You cannot climb out of a bog; struggling sinks you deeper. But crying out is something you CAN do, and the psalm says it is heard. Notice too the waiting: rescue rarely arrives on our schedule. Keep crying out. The mud is not the end of your song.',
   'Where are you still trying to climb when what you need is to cry out — to God and to help?',
   'reflective', 'addiction', array['rescue','waiting','testimony']),
  ('No condemnation',
   'Romans 8:1', 'Romans', 8, 1, null,
   'There is therefore now NO condemnation for those who are in Christ Jesus. Relapse''s deadliest weapon is not craving but shame — the voice that says you are disqualified, so why keep trying. Paul''s "therefore" lands after seven chapters of honest struggle, including his own: the good I want, I do not do. Into exactly that struggle he speaks the verdict: no condemnation. Not "less." None. Shame drives you into hiding, and hiding feeds the addiction. The verdict drives you into the light, where healing happens. Begin again today — not as a defendant, but as someone already acquitted.',
   'Is shame keeping any part of your struggle in hiding right now?',
   'encouragement', 'addiction', array['shame','grace','verdict'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ anger / loneliness ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('The soft answer',
   'Proverbs 15:1', 'Proverbs', 15, 1, null,
   'A soft answer turns away wrath, but a harsh word stirs up anger. The proverb hands you real power in every heated exchange: you choose whether the temperature rises or falls. Softness here is not weakness or surrender — it is strength under control, the deliberate decision not to match the other person''s heat. Escalation always feels justified in the moment; that is its trap. The next time a conversation starts to spark, try the experiment Scripture proposes: answer one notch gentler than what you received, and watch what it does to the room.',
   'Which recurring conflict in your life most needs a one-notch-gentler answer from you?',
   'practical', 'anger', array['gentleness','conflict','words']),
  ('Before the sun goes down',
   'Ephesians 4:26-27', 'Ephesians', 4, 26, 27,
   'Be angry and do not sin; do not let the sun go down on your anger, and give no opportunity to the devil. Paul concedes something important: anger itself is not automatically sin — some things should anger you. The danger is stored anger: nursed overnight, replayed, hardened into resentment. That, he warns, is an open door for the enemy. The sun-down rule is mercy disguised as a deadline: deal with it today — say the honest thing, make the call, or hand it to God — before it sets into something with roots.',
   'What anger are you currently storing overnight — and what would "before sundown" require of you today?',
   'study', 'anger', array['resentment','deadline','release']),
  ('Greater than the mighty',
   'Proverbs 16:32', 'Proverbs', 16, 32, null,
   'Whoever is slow to anger is better than the mighty, and he who rules his spirit than he who takes a city. Scripture ranks self-mastery above conquest — the general who commands armies but not his own temper has won the lesser battle. This re-frames your struggle with anger: every time you pause instead of erupt, absorb instead of retaliate, lower your voice instead of raising it, you are doing something Scripture calls greater than heroics. No one applauds. Heaven notices. Rule the city within first.',
   'What would "ruling your spirit" have looked like in your last blow-up — and how can you pre-decide it for the next one?',
   'reflective', 'anger', array['self-control','strength','patience']),
  ('He goes before you',
   'Deuteronomy 31:8', 'Deuteronomy', 31, 8, null,
   'Moses'' words to Joshua before an intimidating future: the LORD Himself goes before you and will be with you; He will never leave you nor forsake you. Do not be afraid; do not be discouraged. Two prepositions carry the promise — BEFORE you, into the rooms and days you have not entered yet, and WITH you in this one. Loneliness says no one goes where you go or stays when others leave. This verse answers both. You may walk into tomorrow unaccompanied by people. You will not walk into it unaccompanied.',
   'What upcoming situation feels loneliest — and what changes if God is already there before you arrive?',
   'encouragement', 'loneliness', array['presence','courage','future']),
  ('With you always',
   'Matthew 28:20', 'Matthew', 28, 20, null,
   'Jesus'' last recorded words in Matthew are not advice but presence: surely I am with you always, to the very end of the age. He attached the promise to a sending — go, make disciples — which suggests something unexpected about loneliness: His companionship is often felt most strongly by people on mission, not people in hiding. Isolation turns us inward, where the ache echoes. Purpose turns us outward, where He walks. If you feel alone today, the counterintuitive medicine may be to go be with someone for His sake — and find He was with you on the way.',
   'What small mission — a visit, a call, a service — could you accept this week as a way of walking with Him?',
   'reflective', 'loneliness', array['presence','mission','companionship']),
  ('Nowhere You are not',
   'Psalm 139:7-10', 'Psalms', 139, 7, 10,
   'Father, David asked where he could flee from Your presence and found the answer: nowhere. Heaven, the depths, the far side of the sea — even there Your hand leads me and holds me. So I bring You the places that feel farthest: the apartment that''s too quiet, the crowd where no one knows me, the night shift, the hospital room. If there is nowhere You are not, then this lonely place is not actually empty. Open my eyes to the Presence already here, and make me, in time, a presence for someone else''s empty room. Amen.',
   'Name your loneliest place to God right now. What would it mean that He is already in it?',
   'prayer', 'loneliness', array['presence','omnipresence','comfort'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ depression_hope / learning_to_pray ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('New every morning',
   'Lamentations 3:22-23', 'Lamentations', 3, 22, 23,
   'These famous words — His mercies are new every morning; great is Your faithfulness — sit in the middle of a book of funeral songs, written in the rubble of a destroyed city. That location matters. This is not greeting-card optimism; it is hope dug out from under wreckage by a man who has wept honestly for two chapters. Mercies arriving DAILY means you are not asked to have enough for the month, only to receive today''s portion. If depression makes the future unbearable to look at, Lamentations shrinks the assignment: just this morning. His mercy is already in it.',
   'What would it mean to live today on today''s mercies only, without borrowing tomorrow''s weight?',
   'study', 'depression_hope', array['mercy','mornings','faithfulness']),
  ('Through the waters',
   'Isaiah 43:2', 'Isaiah', 43, 2, null,
   'When you pass through the waters, I will be with you — not IF, but WHEN. Scripture does not promise believers a detour around deep water and fire; it promises company in them and a limit on them: the rivers will not sweep you away, the flames will not consume you. Depression often insists this darkness is both endless and unaccompanied. This verse contradicts it twice. You are passing THROUGH — the preposition has an exit — and you are not doing it alone. Keep walking, at whatever pace today allows. Through means through.',
   'What helps you remember, in the middle of deep water, that "through" has an other side?',
   'encouragement', 'depression_hope', array['presence','endurance','through']),
  ('The God of hope',
   'Romans 15:13', 'Romans', 15, 13, null,
   'Father, Paul calls You the God of hope — hope''s source, not just its object. So I stop trying to manufacture optimism and come to be FILLED instead: fill me with all joy and peace in believing, so that by the power of the Holy Spirit I may abound in hope. I confess my tank is empty; some mornings even wanting hope is beyond me. But this prayer puts the burden where Paul put it — on Your filling, not my striving. Begin with a trickle if that is what I can hold today. I am here, empty, and willing. Amen.',
   'Can you pray "fill me" today without also pretending to feel more than you do?',
   'prayer', 'depression_hope', array['hope','filling','spirit']),
  ('Pour out your heart',
   'Psalm 62:8', 'Psalms', 62, 8, null,
   'Trust in Him at all times, O people; pour out your heart before Him — God is a refuge for us. Poured-out prayer is not neat. It is the whole pitcher upended: complaint, fear, confusion, even anger, emptied without pre-editing. Many of us pray in press releases, telling God only what we have already made presentable. The psalms model something rawer and more honest, and the verse gives the reason it is safe: He is a REFUGE — a place you run into, not a panel you audition for. Today, skip the polish. Pour.',
   'What have you been editing out of your prayers that God is waiting to hear unpolished?',
   'reflective', 'learning_to_pray', array['honesty','refuge','lament']),
  ('When you don''t have words',
   'Romans 8:26', 'Romans', 8, 26, null,
   'The Spirit helps us in our weakness, Paul writes — we do not know what to pray for as we ought, but the Spirit Himself intercedes for us with groanings too deep for words. Take the pressure off: even the apostle admits not knowing how to pray. On the days when all you can produce is a sigh from a hospital chair or a wordless ache at the ceiling, prayer has not failed. Something in the Trinity picks up precisely where your vocabulary gives out, translating groans into intercession. Showing up wordless still counts. It may count most.',
   'When words fail you, can you let a sigh in God''s direction be enough?',
   'encouragement', 'learning_to_pray', array['spirit','weakness','intercession']),
  ('Ask, seek, knock',
   'Luke 11:9-10', 'Luke', 11, 9, 10,
   'Ask, and it will be given; seek, and you will find; knock, and the door will be opened. The Greek verbs are continuous: keep asking, keep seeking, keep knocking. Jesus attaches this to a story about a neighbor who answers because of sheer persistence — and then argues from lesser to greater: if flawed fathers give good gifts, how much more your Father in heaven? Persistence in prayer is not nagging a reluctant God; it is taking Him at His word that the door is answerable. Some doors open on the hundredth knock. Keep knocking.',
   'What request have you quietly stopped asking for that Jesus might be inviting you to resume?',
   'study', 'learning_to_pray', array['persistence','asking','fatherhood'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ new_to_christianity / understanding_the_bible ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('A new creation',
   '2 Corinthians 5:17', '2 Corinthians', 5, 17, null,
   'If anyone is in Christ, he is a new creation. The old has passed away; behold, the new has come. New believers often expect to feel instantly different and are troubled when old habits and old guilt still show up. Paul''s claim is about status before it is about feelings: in Christ, your identity has been remade — the verdict, the belonging, the future. The feelings and habits follow slowly, the way a freed prisoner may still dream of his cell for a while. Do not measure the new creation by this week''s emotions. Measure it by His declaration, and grow into what is already true.',
   'Where are you judging your new life by feelings instead of by what God has declared?',
   'encouragement', 'new_to_christianity', array['identity','newness','growth']),
  ('The honest entrance',
   'Romans 10:9', 'Romans', 10, 9, null,
   'If you confess with your mouth that Jesus is Lord and believe in your heart that God raised Him from the dead, you will be saved. Notice how little scaffolding there is: no probation period, no exam, no minimum attendance. Mouth and heart — allegiance declared, resurrection trusted. "Jesus is Lord" was a loaded phrase in a world that said "Caesar is lord"; it still is, in a world of many little lords. Becoming a Christian is not adopting a self-improvement plan. It is switching allegiance to a living King — out loud, and from the heart.',
   'Have you actually said it out loud — and what "little lord" is hardest to hand over to Him?',
   'study', 'new_to_christianity', array['confession','lordship','salvation']),
  ('The right to be called children',
   'John 1:12', 'John', 1, 12, null,
   'To all who received Him, who believed in His name, He gave the RIGHT to become children of God. Not employees on probation. Not fans in the cheap seats. Children — with a right, granted by the only One authorized to grant it. New believers often relate to God like interns hoping not to be fired, working anxiously to justify their place. But a child''s place at the table is not performance-based; it is birth-based, and you have been born into the family. Pray today the way a child talks to a good father: freely, honestly, without a résumé.',
   'Do you approach God more like an intern or a child? What would child-like access change today?',
   'reflective', 'new_to_christianity', array['adoption','identity','access']),
  ('God-breathed and useful',
   '2 Timothy 3:16-17', '2 Timothy', 3, 16, 17,
   'All Scripture is God-breathed and useful — for teaching, rebuking, correcting, and training in righteousness, so that the servant of God may be thoroughly equipped. Notice what Scripture claims for itself: not merely inspiring, but inspired; not merely interesting, but USEFUL, with four listed uses. Reading it, then, is less like touring a museum and more like entering a workshop. A healthy question after any passage: which of the four is happening to me here — am I being taught something new, rebuked for something wrong, corrected onto a better path, or trained in a habit of righteousness?',
   'Take today''s reading: which of the four uses — teach, rebuke, correct, train — is it doing to you?',
   'study', 'understanding_the_bible', array['scripture','inspiration','usefulness']),
  ('Meditate day and night',
   'Joshua 1:8', 'Joshua', 1, 8, null,
   'God told Joshua that the book of the law should not depart from his mouth — he was to meditate on it day and night, careful to do all that is written, and then his way would be prosperous. Biblical meditation is not emptying the mind but filling it: turning a verse over slowly, the way you might turn a hard candy instead of crunching it. Muttering it, questioning it, carrying it into the afternoon. Modern reading rushes; meditation lingers. Try taking one verse — just one — and keeping it in your mouth all day. Depth beats distance.',
   'What one verse will you carry and "chew" through today rather than reading past it?',
   'practical', 'understanding_the_bible', array['meditation','slowness','depth']),
  ('Living and active',
   'Hebrews 4:12', 'Hebrews', 4, 12, null,
   'The word of God is living and active, sharper than any two-edged sword, discerning the thoughts and intentions of the heart. This explains an experience every serious reader eventually has: you sit down to read the Bible, and the Bible reads YOU — a sentence written millennia ago names this week''s exact evasion or wound. Scripture is not an inert text you dissect; it is a scalpel in the Surgeon''s hand. That can sting. But surgical exposure is how healing starts. Come to the text willing to be found, not just informed.',
   'When has a passage recently "read you" — and did you let the exposure lead anywhere?',
   'reflective', 'understanding_the_bible', array['scripture','discernment','exposure'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ understanding_god / returning_to_faith ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('God is love',
   '1 John 4:16', '1 John', 4, 16, null,
   'God IS love, John writes — not merely that God loves, as one activity among many, but that love is His nature, the way heat is fire''s nature. This corrects the private picture many of us carry: a God who is essentially stern, whose love must be coaxed out by good behavior. John says we have come to KNOW and BELIEVE the love God has for us — two verbs, because knowing about it and leaning your weight on it are different things. Whatever else you learn about God this year, it will sit on this foundation or on sand.',
   'Deep down, what do you suspect God''s default expression toward you is — and how does "God is love" challenge it?',
   'reflective', 'understanding_god', array['love','nature','trust']),
  ('Slow to anger, rich in love',
   'Psalm 103:8-10', 'Psalms', 103, 8, 10,
   'The LORD is compassionate and gracious, slow to anger, abounding in love. He does not treat us as our sins deserve. This is God''s self-description, echoed from Sinai onward — the closest thing Scripture has to God stating His own character reference. Notice the economics: anger is slow and finite ("He will not harbor it forever"); love ABOUNDS, overflows the measuring cup. Many of us have the proportions reversed in our imagination — quick wrath, rationed love. Correct the picture, because you will only run toward a God you believe is glad to receive you.',
   'If you truly believed God is "slow to anger, abounding in love," what would you stop hiding from Him?',
   'study', 'understanding_god', array['character','mercy','compassion']),
  ('Higher ways',
   'Isaiah 55:8-9', 'Isaiah', 55, 8, 9,
   'My thoughts are not your thoughts, neither are your ways My ways, declares the LORD. As the heavens are higher than the earth... Context matters: this is not a cold "don''t ask questions." It comes in an invitation to the thirsty, right after a promise of abundant pardon — God''s ways are higher specifically in MERCY, more generous than we would dare design. Still, the verse leaves room for mystery: some of what God allows will not resolve into sense this side of heaven. Trust, then, is not understanding everything. It is knowing the One whose ways exceed yours is the same One who pardons abundantly.',
   'Where do you need to trust God''s higher ways without demanding they first make sense to you?',
   'reflective', 'understanding_god', array['mystery','mercy','trust']),
  ('The years the locusts ate',
   'Joel 2:25', 'Joel', 2, 25, null,
   'I will restore to you the years that the swarming locust has eaten, God promises a devastated people. It is one of Scripture''s boldest words for anyone returning to faith late, or after long wandering: God speaks of restoring TIME — the seasons you assume are simply lost. He does not run the clock backward; He makes the remaining years so fruitful that the devoured ones lose their power to define you. Look at Peter, restored after denial; at Israel, replanted after exile. Come back. The locust years are not the final math.',
   'What "eaten years" have you assumed disqualify you — and can you hand God the arithmetic?',
   'encouragement', 'returning_to_faith', array['restoration','regret','redemption']),
  ('Create in me a clean heart',
   'Psalm 51:10-12', 'Psalms', 51, 10, 12,
   'Father, David prayed this after his worst chapter, so I can pray it after mine: create in me a clean heart, O God, and renew a right spirit within me. Do not cast me from Your presence; restore to me the JOY of Your salvation. I notice David asked for joy back — not just pardon, but gladness. That is what I miss most: the warmth I once had toward You before drift and failure cooled it. You are not tired of me. Begin the renovation today, and let joy be among the first rooms You restore. Amen.',
   'Beyond forgiveness, will you ask God for the joy back too?',
   'prayer', 'returning_to_faith', array['renewal','joy','repentance']),
  ('Faithful and just to forgive',
   '1 John 1:9', '1 John', 1, 9, null,
   'If we confess our sins, He is faithful and just to forgive us our sins and to cleanse us from all unrighteousness. Confession is not information transfer — God already knows. It is agreement: saying the same thing about your sin that He says, out loud, hiding nothing. And notice the character words attached to His response: faithful (He always does it) and JUST (the cross has made forgiving you a matter of justice, not leniency). Returning to God does not begin with cleaning yourself up first. It begins with one honest sentence.',
   'What is the one honest sentence of confession you have been postponing?',
   'study', 'returning_to_faith', array['confession','cleansing','honesty'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ financial_wisdom / discipline / confidence ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Great gain',
   '1 Timothy 6:6-8', '1 Timothy', 6, 6, 8,
   'Godliness with contentment is great gain, Paul writes — for we brought nothing into the world, and we can take nothing out. In a culture that measures gain in accumulation, Scripture proposes a different portfolio: a godly life plus a heart at rest with enough. Contentment is not passivity about poverty or an excuse to stop planning; it is freedom from the treadmill that turns every raise into a new baseline. Food and covering, Paul says, can be enough. Ask the subversive question today: what do I already have that I once prayed for?',
   'What are you currently treating as a need that is really an escalated want?',
   'study', 'financial_wisdom', array['contentment','enough','gain']),
  ('Never will I leave you — the money verse',
   'Hebrews 13:5', 'Hebrews', 13, 5, null,
   'Keep your life free from the love of money, and be content with what you have — and then the writer gives the strange-seeming reason: for He has said, "Never will I leave you; never will I forsake you." Why answer money-love with a presence-promise? Because the love of money is usually fear wearing a disguise: fear of abandonment, of being uncared for, of facing the future alone. The account balance is a security blanket. God''s answer is not a number; it is Himself, permanently. Contentment grows exactly as deep as that promise is believed.',
   'What fear is underneath your money anxiety — and how does "never will I forsake you" answer it?',
   'reflective', 'financial_wisdom', array['contentment','fear','presence']),
  ('Run to win',
   '1 Corinthians 9:24-25', '1 Corinthians', 9, 24, 25,
   'Everyone who competes exercises self-control in all things, Paul observes — athletes accept strict training for a wreath that wilts. Then the turn: we discipline ourselves for a crown that lasts forever. Notice that Paul does not scold desire; he redirects it. Discipline is not the enemy of joy but its training plan — no runner resents the workouts that make the race winnable. The question for your spiritual life is an athlete''s question: what is my training plan? Vague intentions produce vague Christians. A time, a place, a practice: start there.',
   'What would a realistic "training plan" for your walk with God look like this month — concretely?',
   'practical', 'discipline', array['training','self-control','perseverance']),
  ('Seven falls, eight risings',
   'Proverbs 24:16', 'Proverbs', 24, 16, null,
   'The righteous falls seven times — and rises again. Notice what makes him righteous in this proverb: not the absence of falling but the habit of rising. Many people abandon spiritual disciplines at the first lapse; the missed week becomes a missed month becomes a quietly closed book. Scripture''s realism is kinder and sturdier: falling is assumed. The distinguishing mark of the righteous is simply that they get up one more time than they fall. Broke the streak? The godly move is not self-disgust. It is standing up, today, without ceremony.',
   'Where did you fall recently — and what would an unceremonious "getting up" look like today?',
   'encouragement', 'discipline', array['resilience','failure','rising']),
  ('The strength verse, in context',
   'Philippians 4:13', 'Philippians', 4, 13, null,
   'I can do all things through Him who strengthens me — printed on locker rooms and coffee mugs, usually meaning "I can achieve anything." Paul meant something better. He has just said he learned the secret of contentment in EVERY circumstance: well-fed or hungry, abundance or need. "All things" is that list. The promise is not unlimited achievement; it is unbreakable sufficiency — Christ''s strength to stand in whatever state you find yourself, including the low ones. Which means the verse belongs not to your ambitions first, but to your worst Tuesday. There, too, He strengthens.',
   'Which current circumstance — especially a low one — needs this verse''s real meaning?',
   'study', 'confidence', array['contentment','strength','context']),
  ('Strong and courageous',
   'Joshua 1:9', 'Joshua', 1, 9, null,
   'Father, You commanded Joshua: be strong and courageous; do not be frightened, do not be dismayed — for the LORD your God is with you wherever you go. I notice courage is commanded, which means it cannot depend on how I feel; and I notice the reason given is not Joshua''s ability but Your company. So for the thing in front of me that shrinks me — the conversation, the decision, the new beginning — I take the command and the reason together. I will go, not because I am sure of myself, but because You go wherever I go. Make my steps steady today. Amen.',
   'What is the specific thing you are being called to do afraid — with Him?',
   'prayer', 'confidence', array['courage','presence','obedience'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

-- ============ career / motivation / leadership ============
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Commit your work',
   'Proverbs 16:3', 'Proverbs', 16, 3, null,
   'Commit your work to the LORD, and your plans will be established. The Hebrew for commit is literally "roll" — roll your work onto Him, the way you would roll a boulder you cannot carry. This is different from asking God to bless plans you have already finalized. Committing happens at the start: the project, the job search, the business decision, rolled onto His strength and submitted to His editing. The promise is establishment — not that every plan succeeds as drafted, but that a committed life gets built on ground that holds.',
   'Are you asking God to bless finished plans, or rolling the work onto Him at the start?',
   'practical', 'career', array['planning','surrender','work']),
  ('Work was in the garden',
   'Genesis 2:15', 'Genesis', 2, 15, null,
   'The LORD God took the man and put him in the garden of Eden to work it and keep it. Note the timing: this is BEFORE the fall. Work is not the curse — thorns and futility came later; work itself belongs to paradise. That re-dignifies what you do: cultivating, building, coding, teaching, tending are ways humans bear the image of a working God. If your job feels like mere survival, this verse quietly raises its status. And if you are between jobs, your worth was never your title: the Gardener assigned the garden, and He assigns the next one too.',
   'What would change this week if you saw your work as garden-keeping under God rather than survival?',
   'study', 'career', array['vocation','dignity','creation']),
  ('The race marked out',
   'Hebrews 12:1-2', 'Hebrews', 12, 1, 2,
   'Since we are surrounded by so great a cloud of witnesses, let us throw off everything that hinders and run with endurance the race MARKED OUT for us — looking to Jesus. Three motivations in two verses: a stadium of finished saints proving it can be done; a race that is yours, not a comparison with anyone else''s lane; and a fixed gaze on the One at the finish line. Motivation dies from heavy baggage and wandering eyes. Ask what needs throwing off — not just sins, but hindrances, even good things that slow your particular race — and look up.',
   'What hindrance — possibly a good thing — do you need to throw off to run your marked-out race?',
   'encouragement', 'motivation', array['endurance','focus','witnesses']),
  ('In word or deed',
   'Colossians 3:17', 'Colossians', 3, 17, null,
   'Whatever you do, in word or deed, do everything in the name of the Lord Jesus, giving thanks to God the Father through Him. Paul erases the line between sacred and secular hours: EVERYTHING — emails, errands, workouts, conversations — can be done in His name, which means as His representative, with His character, for His honor. This turns an ordinary day into a liturgy and solves the motivation problem at its root: you are never doing nothing that matters. The task in front of you right now is signable work. Sign it well.',
   'Take your next mundane task today: what does doing it "in His name" actually change about how you do it?',
   'reflective', 'motivation', array['wholeness','ordinary','thanksgiving']),
  ('In humility, count others first',
   'Philippians 2:3-4', 'Philippians', 2, 3, 4,
   'Do nothing from selfish ambition or vain conceit, but in humility count others more significant than yourselves — looking not only to your own interests but also to the interests of others. Paul is describing the mindset of Christ, and it reads like an inverted leadership manual: influence built on elevating the people around you. Practically, this looks like credit given away, questions asked before opinions issued, and decisions weighed by their cost to the least powerful person in the room. Leaders shaped by this verse are rare enough that people never forget working for one.',
   'Whose interests, in your current role, do you most habitually overlook — and what would "counting them first" change this week?',
   'reflective', 'leadership', array['humility','service','influence']),
  ('An example in speech and conduct',
   '1 Timothy 4:12', '1 Timothy', 4, 12, null,
   'Paul told young Timothy: let no one despise you for your youth, but set the believers an example in speech, in conduct, in love, in faith, in purity. Notice the strategy for winning respect you have not yet been granted: not self-promotion, not demanding the title — example. Five arenas, all of them available to you regardless of age, position, or platform. Leadership, in Scripture''s economy, is credibility accumulated through consistency when no one is obligated to follow you. Whatever room you feel too junior for: be the example first. Authority tends to follow.',
   'In which of the five arenas — speech, conduct, love, faith, purity — is your example thinnest right now?',
   'encouragement', 'leadership', array['example','credibility','youth'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);

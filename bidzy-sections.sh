#!/bin/bash
# Proof band, the tension, three cards, the arithmetic, limitations,
# FAQ and close. Run from the project root.
set -e
[ -f index.html ] || { echo "Run from the bidzy project root."; exit 1; }

python3 - << 'PY'
p = "index.html"
s = open(p).read()

# ---------------- styles ----------------
s = s.replace(
"  /* temporary, so there is something to scroll against */\n  .placeholder{height:90vh;padding-top:80px;text-align:center;color:#2E2E2B;font-size:13px}",
"""  /* shared section rhythm */
  section.s{padding:0 16px}
  @media (min-width:640px){ section.s{padding:0 32px} }
  @media (min-width:1024px){ section.s{padding:0 30px} }
  .wrap{max-width:1160px;margin:0 auto}
  .wrap-narrow{max-width:860px;margin:0 auto}

  .eyebrow{
    display:flex;align-items:center;gap:9px;
    margin-bottom:18px;
  }
  .eyebrow i{height:3px;width:18px;border-radius:2px;background:var(--accent);display:block}
  .eyebrow span{
    font-family:var(--mono);font-size:11px;letter-spacing:.08em;
    text-transform:uppercase;color:#6E6C66;
  }

  h2{
    font-size:clamp(26px,4.4vw,44px);font-weight:400;line-height:1.04;
    letter-spacing:-.5px;text-wrap:balance;
  }
  .sub{
    margin-top:18px;font-size:clamp(15px,1.4vw,18px);line-height:1.7;
    color:var(--muted);max-width:60ch;text-wrap:balance;
  }

  /* proof band */
  .proof{
    margin-top:clamp(24px,4vw,56px);
    border-top:1px solid var(--line);border-bottom:1px solid var(--line);
    display:grid;grid-template-columns:1fr 1fr;
  }
  @media (min-width:900px){ .proof{grid-template-columns:repeat(4,1fr)} }
  .proof div{
    padding:clamp(24px,3vw,40px) clamp(16px,2.2vw,32px);
    border-right:1px solid var(--line);border-bottom:1px solid var(--line);
  }
  @media (min-width:900px){
    .proof div{border-bottom:0}
    .proof div:last-child{border-right:0}
  }
  @media (max-width:899px){
    .proof div:nth-child(2n){border-right:0}
    .proof div:nth-child(n+3){border-bottom:0}
  }
  .proof b{
    display:block;font-size:clamp(28px,4vw,42px);font-weight:400;
    letter-spacing:-1px;line-height:1;
  }
  .proof p{
    margin-top:12px;font-size:13.5px;line-height:1.55;color:var(--muted);
  }

  /* the uncomfortable bit */
  .tension{
    padding-top:clamp(88px,13vw,180px);padding-bottom:clamp(88px,13vw,180px);
    text-align:center;
  }
  .tension h2{max-width:22ch;margin:0 auto}
  .tension em{font-style:italic;color:#C8B48A}

  /* three cards */
  .cards{
    display:grid;gap:14px;margin-top:clamp(32px,4vw,52px);
  }
  @media (min-width:860px){ .cards{grid-template-columns:repeat(3,1fr)} }
  .card{
    border:1px solid var(--line);border-radius:14px;
    padding:clamp(22px,2.4vw,30px);
    background:rgba(255,255,255,.015);
  }
  .card.hl{background:rgba(47,127,255,.05);border-color:rgba(47,127,255,.22)}
  .card h3{font-size:17px;font-weight:500;letter-spacing:-.3px;margin-bottom:10px}
  .card p{font-size:14px;line-height:1.7;color:var(--muted)}
  .card .tag{
    font-family:var(--mono);font-size:10.5px;letter-spacing:.08em;
    text-transform:uppercase;color:#6E6C66;display:block;margin-bottom:14px;
  }

  /* the arithmetic */
  .sum{
    margin-top:clamp(32px,4vw,52px);
    display:grid;gap:12px;align-items:stretch;
  }
  @media (min-width:760px){ .sum{grid-template-columns:1fr auto 1fr auto 1fr} }
  .sum-box{
    border:1px solid var(--line);border-radius:14px;
    padding:clamp(20px,2.2vw,28px);
  }
  .sum-box .k{
    font-family:var(--mono);font-size:10.5px;letter-spacing:.08em;
    text-transform:uppercase;color:#6E6C66;
  }
  .sum-box .v{
    display:block;margin-top:14px;font-size:clamp(26px,3.4vw,36px);
    font-weight:400;letter-spacing:-1px;line-height:1;
  }
  .sum-box .n{margin-top:12px;font-size:13px;line-height:1.6;color:var(--muted)}
  .sum-box.warn{background:rgba(201,156,78,.05);border-color:rgba(201,156,78,.22)}
  .sum-box.warn .v{color:#E0A85A}
  .sum-box.good{background:rgba(74,222,128,.05);border-color:rgba(74,222,128,.22)}
  .sum-box.good .v{color:#5DD68E}
  .sum-op{
    display:grid;place-items:center;color:#55534E;font-size:24px;
    padding:4px 0;
  }

  /* limitations */
  .limits{display:grid;gap:0;margin-top:clamp(28px,3.4vw,44px);
    border-top:1px solid var(--line)}
  .limits div{
    padding:22px 0;border-bottom:1px solid var(--line);
    display:grid;gap:6px;
  }
  @media (min-width:760px){
    .limits div{grid-template-columns:240px 1fr;gap:32px;align-items:baseline}
  }
  .limits b{font-weight:450;font-size:15px}
  .limits p{font-size:14px;line-height:1.65;color:var(--muted)}

  /* faq */
  .faq{margin-top:clamp(28px,3.4vw,44px);border-top:1px solid var(--line)}
  .faq details{border-bottom:1px solid var(--line)}
  .faq summary{
    list-style:none;cursor:pointer;padding:22px 40px 22px 0;position:relative;
    font-size:16px;font-weight:450;letter-spacing:-.2px;
  }
  .faq summary::-webkit-details-marker{display:none}
  .faq summary::after{
    content:'+';position:absolute;right:6px;top:20px;
    color:#6E6C66;font-size:20px;font-weight:300;transition:transform 200ms;
  }
  .faq details[open] summary::after{content:'−'}
  .faq p{padding:0 0 24px;font-size:14.5px;line-height:1.75;color:var(--muted);max-width:70ch}

  /* close */
  .close{
    padding-top:clamp(88px,13vw,170px);padding-bottom:clamp(64px,8vw,110px);
    text-align:center;
  }
  .close h2{max-width:20ch;margin:0 auto}

  footer{
    border-top:1px solid var(--line);
    padding:36px 16px;
  }
  @media (min-width:640px){ footer{padding:36px 32px} }
  .foot{
    max-width:1160px;margin:0 auto;
    display:flex;flex-wrap:wrap;align-items:center;gap:16px;
    font-size:13px;color:#6E6C66;
  }
  .foot a{color:var(--muted);text-decoration:none}
  .foot a:hover{color:var(--ink)}
  .foot .right{margin-left:auto;display:flex;gap:20px;flex-wrap:wrap}""")

# ---------------- markup ----------------
s = s.replace(
'<div class="placeholder">next: the arithmetic</div>',
"""<section class="s" id="proof">
  <div class="wrap">
    <div class="proof">
      <div>
        <b class="num">$4,900</b>
        <p>of work the cheapest quote left out, priced from what the others charged for it</p>
      </div>
      <div>
        <b class="num">2</b>
        <p>follow-ups before Bidzy stops emailing and tells you to pick up the phone</p>
      </div>
      <div>
        <b class="num">9 days</b>
        <p>from the first email to a price you can trust, with nobody watching it</p>
      </div>
      <div>
        <b class="num">0</b>
        <p>accounts a contractor has to create to be part of this</p>
      </div>
    </div>
  </div>
</section>

<section class="s tension">
  <div class="wrap-narrow">
    <h2>A wrong price is still a number.<br><em>You find out when the skip arrives and nobody ordered it.</em></h2>
  </div>
</section>

<section class="s" id="how">
  <div class="wrap">
    <div class="eyebrow"><i></i><span>What it does</span></div>
    <h2>Three things you would otherwise do yourself, badly, at midnight.</h2>

    <div class="cards">
      <div class="card">
        <span class="tag">01 — the chase</span>
        <h3>It keeps asking</h3>
        <p>Most contractors never reply. Bidzy follows up on day three, again on day seven, then stops and tells you the company needs a phone call. It does this every morning whether or not you have opened the app.</p>
      </div>
      <div class="card hl">
        <span class="tag">02 — the reading</span>
        <h3>It reads anything they send</h3>
        <p>A tidy PDF, a scanned page, or “call it fourteen two all in, you sort the skip.” All three come out as the same thing: a total, what is included, and what is not.</p>
      </div>
      <div class="card">
        <span class="tag">03 — the memory</span>
        <h3>It knows which prices died</h3>
        <p>Change the material and only the quotes that depended on it go stale. Anyone who already priced the new one survives, the ranking updates, and the rest get emailed to ask whether their number still holds.</p>
      </div>
    </div>
  </div>
</section>

<section class="s" id="arithmetic" style="padding-top:clamp(88px,13vw,170px)">
  <div class="wrap">
    <div class="eyebrow"><i></i><span>The arithmetic</span></div>
    <h2>Crown quoted the lowest number and the highest price.</h2>
    <p class="sub">Every exclusion is priced using what the other contractors charged for that same work. Nothing here is estimated — it is what this market costs, learned from the quotes on the board.</p>

    <div class="sum">
      <div class="sum-box">
        <span class="k">They quoted</span>
        <span class="v num">$11,900</span>
        <p class="n">The number in the email. The one you would have picked.</p>
      </div>
      <div class="sum-op">+</div>
      <div class="sum-box warn">
        <span class="k">Work left out</span>
        <span class="v num">$4,900</span>
        <p class="n">Removal and disposal, delivery, skip hire, sales tax. Yours to arrange.</p>
      </div>
      <div class="sum-op">=</div>
      <div class="sum-box good">
        <span class="k">Real cost</span>
        <span class="v num">$16,800</span>
        <p class="n">The dearest quote on the board, and the one that looked cheapest.</p>
      </div>
    </div>
  </div>
</section>

<section class="s" id="limits" style="padding-top:clamp(88px,13vw,170px)">
  <div class="wrap">
    <div class="eyebrow"><i></i><span>What it does not do</span></div>
    <h2>The parts that are honest about being unfinished.</h2>

    <div class="limits">
      <div>
        <b>Licence checks are NYC only</b>
        <p>It queries the Department of Consumer and Worker Protection register directly. A company not on that register comes back unverified rather than assumed fine.</p>
      </div>
      <div>
        <b>It does not find contractors</b>
        <p>You bring the companies. Discovery is the obvious next piece and it is not built.</p>
      </div>
      <div>
        <b>The reader is sometimes unsure</b>
        <p>When it cannot find a price it trusts, it says so and asks you to read the email yourself. That is better than a confident wrong number on a board about honest pricing.</p>
      </div>
      <div>
        <b>One project, no accounts</b>
        <p>Built in eight days for a hackathon. The architecture supports more; the interface does not yet.</p>
      </div>
    </div>
  </div>
</section>

<section class="s" style="padding-top:clamp(88px,13vw,170px)">
  <div class="wrap-narrow">
    <div class="eyebrow"><i></i><span>Questions</span></div>
    <h2>Reasonable objections.</h2>

    <div class="faq">
      <details>
        <summary>Isn't this just a form?</summary>
        <p>A form requires the contractor to fill it in, which is exactly the thing they will not do. Bidzy sends an ordinary email and reads an ordinary reply. The contractor does nothing different from what they already do fifty times a week.</p>
      </details>
      <details>
        <summary>Where does the “work left out” figure come from?</summary>
        <p>From the other quotes. If two contractors priced removal at $2,400 and $2,600, then removal costs about $2,500 on this job, and a quote that excludes it is $2,500 cheaper than it looks. Add a third quote and the figure sharpens.</p>
      </details>
      <details>
        <summary>What happens if nobody replies?</summary>
        <p>Two follow-ups, spaced three and four days apart, sent on a schedule with nobody watching. Then it stops and writes that the company needs a phone call. A third email does not work, and a system that keeps trying forever is just abandoning the job politely.</p>
      </details>
      <details>
        <summary>Does it email real contractors?</summary>
        <p>In this demo, no. The companies are real names checked against a real register, but the addresses are ones we control. Cold-emailing actual businesses from a hackathon build would be spam.</p>
      </details>
      <details>
        <summary>Why email rather than a portal?</summary>
        <p>Because every previous attempt was a portal and they all failed on the supply side. A four-person roofing company will not create an account for one job they might not win. Email is the only thing both sides already have.</p>
      </details>
      <details>
        <summary>What is it built on?</summary>
        <p>Convex for the backend, with quote intelligence and licence compliance as separate isolated components. AgentMail for the inbox. Firecrawl for reading quote documents and querying the city register. Groq for reading plain email into the same shape.</p>
      </details>
    </div>
  </div>
</section>

<section class="s close">
  <div class="wrap-narrow">
    <h2>None of these contractors installed Bidzy.<br>They just answered an email.</h2>
    <div class="cta" style="justify-content:center;margin-top:34px">
      <a class="pill-lg solid" href="/app/index.html">
        <svg width="14" height="17" viewBox="0 0 100 121" fill="none" aria-hidden="true">
          <path fill="#0C0C0C" fill-rule="evenodd"
            d="M40 0H66C88 0 94 13 94 30C94 48 88 61 78 61H40L4 30ZM36 30L54 15V46Z
               M40 61H70C92 61 100 74 100 91C100 108 92 121 70 121H42L4 91ZM36 91L54 76V107Z"/>
        </svg>
        Open Bidzy
      </a>
    </div>
  </div>
</section>

<footer>
  <div class="foot">
    <span>Bidzy — built in eight days for the Convex All Gas Hackathon.</span>
    <span class="right">
      <a href="/app/index.html">Open the app</a>
      <a href="https://github.com/Kingnanaweb3/bidzy">GitHub</a>
      <a href="https://github.com/Kingnanaweb3/bidzy/blob/main/hackathon.md">Build log</a>
    </span>
  </div>
</footer>""")

open(p, "w").write(s)
print("all sections in")
PY

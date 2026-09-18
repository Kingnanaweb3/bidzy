import { useState } from "react";
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Sidebar from "./components/Sidebar";
import Header from "./components/Header";
import ComparePage from "./pages/Compare";
import InboxPage from "./pages/InboxPage";
import DocsPage from "./pages/DocsPage";
import ActivityPage from "./pages/ActivityPage";
import ProjectsPage from "./pages/ProjectsPage";
import BudgetPage from "./pages/BudgetPage";

const TITLES = {
  compare: ["Price comparison", "Every price, compared like for like."],
  inbox: ["Inbox", "Companies reply here. They never sign in."],
  docs: ["Documents", "Quote PDFs, read into numbers."],
  activity: ["Activity", "Everything that has happened on this job."],
  projects: ["Projects", "Work you are getting priced."],
  budget: ["Budget", "What this job will really cost."],
};

export default function App() {
  const [page, setPage] = useState("compare");
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project) return <Splash text="No project yet. Run the seed to start one." />;

  const [title, note] = TITLES[page];

  return (
    <div className="min-h-screen bg-[#171717] lg:p-3">
      <div className="lg:flex lg:gap-3">
        <Sidebar project={project} job={job} page={page} onNavigate={setPage} />
        <div className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A] overflow-hidden">
          <Header
            project={project}
            title={title}
            note={note}
            showScopeAction={page === "compare"}
          />
          <main className="px-6 pb-8">
            {!job ? (
              <Splash text="No job on this project yet." />
            ) : page === "compare" ? (
              <ComparePage jobId={job._id} project={project} />
            ) : page === "inbox" ? (
              <InboxPage job={job} jobId={job._id} />
            ) : page === "docs" ? (
              <DocsPage jobId={job._id} />
            ) : page === "activity" ? (
              <ActivityPage projectId={project._id} />
            ) : page === "projects" ? (
              <ProjectsPage projects={projects} jobs={jobs} />
            ) : (
              <BudgetPage jobId={job._id} />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

function Splash({ text }) {
  return (
    <div className="min-h-[60vh] grid place-items-center text-[#5A5A5A] text-sm">
      {text}
    </div>
  );
}

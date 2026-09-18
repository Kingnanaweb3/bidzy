import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Board from "./components/Board";
import Feed from "./components/Feed";
import Header from "./components/Header";
import Inbox from "./components/Inbox";
import ReadDoc from "./components/ReadDoc";
import Sidebar from "./components/Sidebar";
import Stats from "./components/Stats";

export default function App() {
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project) return <Splash text="No project yet. Run the seed to start one." />;

  return (
    <div className="min-h-screen bg-[#171717] lg:p-3">
      <div className="lg:flex lg:gap-3">
        <Sidebar project={project} job={job} />
        <div className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A]">
          <Header project={project} />
          <main className="px-5 sm:px-7 pb-10">
            {job ? (
              <>
                <Stats jobId={job._id} project={project} />
                <div className="grid grid-cols-1 2xl:grid-cols-[minmax(0,1fr)_330px] gap-5 mt-5">
                  <div className="min-w-0 space-y-5">
                    <Board jobId={job._id} />
                    <Inbox job={job} jobId={job._id} />
                    <Docs jobId={job._id} />
                  </div>
                  <Feed projectId={project._id} />
                </div>
              </>
            ) : (
              <Splash text="No job on this project yet." />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

function Docs({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return null;
  return <ReadDoc jobId={jobId} rows={data.rows} />;
}

function Splash({ text }) {
  return (
    <div className="min-h-screen grid place-items-center text-[#5A5A5A] text-sm">
      {text}
    </div>
  );
}

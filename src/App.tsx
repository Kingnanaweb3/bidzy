import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Board from "./components/Board";
import Feed from "./components/Feed";
import Header from "./components/Header";
import Inbox from "./components/Inbox";

export default function App() {
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project)
    return <Splash text="No project yet - run: npx convex run seed:demo" />;

  return (
    <div className="min-h-screen">
      <Header project={project} />
      <main className="mx-auto max-w-[1400px] px-6 py-8 grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-8">
        <div>
          {job ? (
            <>
              <Board jobId={job._id} />
              <Inbox job={job} jobId={job._id} />
            </>
          ) : (
            <Splash text="No job yet" />
          )}
        </div>
        <Feed projectId={project._id} />
      </main>
    </div>
  );
}

function Splash({ text }) {
  return (
    <div className="min-h-screen grid place-items-center text-stone-400 text-sm">
      {text}
    </div>
  );
}

defmodule BorsNG.Worker.Batcher.Message do
  @moduledoc """
  User-readable strings that go in commit messages and comments.
  """

  def generate_status(:waiting) do
    {"Waiting in queue", :running}
  end
  def generate_status(:canceled) do
    {"Canceled", :error}
  end
  def generate_status(:running) do
    {"Running", :running}
  end
  def generate_status(:ok) do
    {"Build succeeded", :ok}
  end
  def generate_status(:error) do
    {"Build failed", :error}
  end
  def generate_status(:timeout) do
    {"Timed out", :error}
  end
  def generate_status(:conflict) do
    {"Merge conflict", :error}
  end

  def generate_message({:preflight, :blocked_labels}) do
    ":-1: Rejected by label"
  end
  def generate_message({:preflight, :pr_status}) do
    ":-1: Rejected by PR status"
  end
  def generate_message(:not_awaiting_review) do
    "Not awaiting review"
  end
  def generate_message({:config, message}) do
    "# Configuration problem\n#{message}"
  end
  def generate_message({:conflict, :failed}) do
    "# Merge conflict"
  end
  def generate_message({:conflict, :retrying}) do
    "# Merge conflict (retrying...)"
  end
  def generate_message({:timeout, :failed}) do
    "# Timed out"
  end
  def generate_message({:timeout, :retrying}) do
    "# Timed out (retrying...)"
  end
  def generate_message({:canceled, :failed}) do
    "# Canceled"
  end
  def generate_message({:canceled, :retrying}) do
    "# Canceled (will resume)"
  end
  def generate_message(:ci_skip) do
    "Has [ci skip], bors build will time out"
  end
  def generate_message({state, statuses}) do
    msg = case state do
      :succeeded -> "Build succeeded"
      :failed -> "Build failed"
      :retrying -> "Build failed (retrying...)"
    end
    Enum.reduce(statuses, "# #{msg}", &gen_status_link/2)
  end
  defp gen_status_link(status, acc) do
    status_link = case status.url do
      nil -> status.identifier
      url -> "[#{status.identifier}](#{url})"
    end
    "#{acc}\n  * #{status_link}"
  end

  def generate_commit_message(patch_links, cut_body_after) do
    patch_links = Enum.sort_by(patch_links, &(&1.patch.pr_xref))
    commit_title = Enum.reduce(patch_links,
      "Merge", &"#{&2} \##{&1.patch.pr_xref}")
    commit_body = Enum.reduce(patch_links, "", fn link, acc ->
      body = cut_body(link.patch.body, cut_body_after)
      author = case link.patch.author do
        nil -> "[unknown]"
        author -> author.login
      end
      reviewer = link.reviewer
      title = link.patch.title
      number = link.patch.pr_xref
      """
      #{acc}
      #{number}: #{title} r=#{reviewer} a=#{author}

      #{body}
      """
    end)
    "#{commit_title}\n#{commit_body}"
  end

  def cut_body(body, nil), do: body
  def cut_body(body, cut) do
    body
    |> String.splitter(cut)
    |> Enum.at(0)
  end

  def generate_bors_toml_error(:parse_failed) do
    "bors.toml: syntax error"
  end

  def generate_bors_toml_error(:empty_config) do
    "bors.toml: does not specify anything to gate on"
  end

  def generate_bors_toml_error(:fetch_failed) do
    "bors.toml: not found"
  end

  def generate_bors_toml_error(:timeout_sec) do
    "bors.toml: expected timeout_sec to be an integer"
  end

  def generate_bors_toml_error(:status) do
    "bors.toml: expected status to be a list"
  end

  def generate_bors_toml_error(:blocked_labels) do
    "bors.toml: expected blocked_labels to be a list"
  end

  @doc """
  Generate the GitHub comment for when staging.tmp is being built.
  By default, this doesn't say anything; it's only applicable when we're
  using a recognized CI system, and, as a result, know the fix.
  """
  def generate_staging_tmp_message("continuous-integration/travis-ci/push") do
    """
    Travis CI is building the `staging.tmp` branch.
    This is not necessary.
    It wastes time, and makes your build and everyone else's slow.

    To do this, you can add this to your `.travis.yml` file,
    if you only care about staging, trying, and the pull request statuses:

        branches:
          only:
            - master
            - staging
            - trying

    Alternatively, you can add this to only turn off `staging.tmp`:

        branches:
          except:
            - staging.tmp
    """
  end
  def generate_staging_tmp_message("continuous-integration/appveyor/branch") do
    """
    AppVeyor is building the `staging.tmp` branch.
    This is not necessary.
    It wastes time, and makes your build and everyone else's slow.

    To do this, you can add this to your `appveyor.yml` file,
    if you only care about pull requests, staging, and trying:

        branches:
          only:
            - master
            - staging
            - trying

    Alternatively, you can add this to only turn off `staging.tmp`:

        branches:
          except:
            - staging.tmp
    """
  end
  def generate_staging_tmp_message(_context) do
    nil
  end
end
